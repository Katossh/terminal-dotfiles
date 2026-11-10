use std::collections::HashSet;
use std::env;
use std::io::{self, Read};
use std::process::ExitCode;

const MAX_RESULTS: usize = 5;

#[derive(Debug, Eq, PartialEq)]
struct Candidate {
    distance: usize,
    name: String,
}

fn edit_distance_with_limit(left: &str, right: &str, limit: usize) -> Option<usize> {
    let left: Vec<char> = left.chars().collect();
    let right: Vec<char> = right.chars().collect();
    let left_len = left.len();
    let right_len = right.len();

    if left_len.abs_diff(right_len) > limit {
        return None;
    }

    let sentinel = limit + 1;

    // Three rows are sufficient for optimal-string-alignment distance:
    // previous_previous is needed only for adjacent transpositions.
    let mut previous = vec![sentinel; right_len + 1];
    for (column, cell) in previous
        .iter_mut()
        .enumerate()
        .take(limit.min(right_len) + 1)
    {
        *cell = column;
    }
    let mut previous_previous = vec![sentinel; right_len + 1];

    for row in 1..=left_len {
        let mut current = vec![sentinel; right_len + 1];
        if row <= limit {
            current[0] = row;
        }

        let start = row.saturating_sub(limit).max(1);
        let end = (row + limit).min(right_len);

        if start <= end {
            for column in start..=end {
                let substitution_cost = if left[row - 1] == right[column - 1] {
                    0
                } else {
                    1
                };

                let deletion = previous[column].saturating_add(1).min(sentinel);
                let insertion = current[column - 1].saturating_add(1).min(sentinel);
                let substitution = previous[column - 1]
                    .saturating_add(substitution_cost)
                    .min(sentinel);

                let mut best = deletion.min(insertion).min(substitution);

                if row > 1
                    && column > 1
                    && left[row - 1] == right[column - 2]
                    && left[row - 2] == right[column - 1]
                {
                    let transposition = previous_previous[column - 2]
                        .saturating_add(1)
                        .min(sentinel);
                    best = best.min(transposition);
                }

                current[column] = best;
            }
        }

        previous_previous = previous;
        previous = current;
    }

    let distance = previous[right_len];
    (distance <= limit).then_some(distance)
}

fn is_candidate_name(name: &str, query: &str) -> bool {
    !name.is_empty()
        && !name.starts_with('_')
        && name != query
        && !name.contains('/')
        && !name.chars().any(char::is_whitespace)
}

fn rank_candidates<'a>(query: &str, names: impl IntoIterator<Item = &'a str>) -> Vec<Candidate> {
    let query_len = query.chars().count();
    if query_len < 2 || query.contains('/') || query.chars().any(char::is_whitespace) {
        return Vec::new();
    }

    let limit = if query_len < 6 { 1 } else { 2 };
    let mut seen = HashSet::new();
    let mut ranked = Vec::new();

    for name in names {
        if !is_candidate_name(name, query) || !seen.insert(name) {
            continue;
        }

        if let Some(distance) = edit_distance_with_limit(query, name, limit) {
            ranked.push(Candidate {
                distance,
                name: name.to_owned(),
            });
        }
    }

    ranked.sort_unstable_by(|left, right| {
        left.distance
            .cmp(&right.distance)
            .then_with(|| left.name.cmp(&right.name))
    });
    ranked.truncate(MAX_RESULTS);
    ranked
}

fn run() -> io::Result<bool> {
    let mut args = env::args_os();
    let _program = args.next();
    let Some(query) = args.next().and_then(|value| value.into_string().ok()) else {
        return Ok(false);
    };

    if args.next().is_some() {
        return Ok(false);
    }

    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;

    let suggestions = rank_candidates(&query, input.lines());
    for candidate in &suggestions {
        println!("{}", candidate.name);
    }

    Ok(!suggestions.is_empty())
}

fn main() -> ExitCode {
    match run() {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::from(1),
        Err(error) => {
            eprintln!("dots-suggest: {error}");
            ExitCode::from(2)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{edit_distance_with_limit, rank_candidates};

    #[test]
    fn adjacent_transposition_is_one_edit() {
        assert_eq!(edit_distance_with_limit("gti", "git", 1), Some(1));
    }

    #[test]
    fn insertion_is_counted() {
        assert_eq!(edit_distance_with_limit("gti", "grit", 2), Some(2));
    }

    #[test]
    fn identical_strings_have_zero_distance() {
        assert_eq!(edit_distance_with_limit("git", "git", 1), Some(0));
    }

    #[test]
    fn values_over_the_threshold_are_rejected() {
        assert_eq!(edit_distance_with_limit("abcdefgh", "xyz", 2), None);
    }

    #[test]
    fn results_are_deduplicated_and_sorted_by_distance_then_name() {
        let names = [
            "abcxefg",
            "abcdefh",
            "abcde",
            "abxyefg",
            "abcxefg",
            "_abcdefg_internal",
            "path/abcdefg",
            "abc defg",
        ];

        let ranked = rank_candidates("abcdefg", names);
        let names: Vec<_> = ranked.into_iter().map(|candidate| candidate.name).collect();

        assert_eq!(names, ["abcdefh", "abcxefg", "abcde", "abxyefg"]);
    }

    #[test]
    fn unicode_names_are_compared_by_characters() {
        assert_eq!(edit_distance_with_limit("café", "cafe", 1), Some(1));
    }

    #[test]
    fn short_and_path_like_queries_are_ignored() {
        assert!(rank_candidates("x", ["git"]).is_empty());
        assert!(rank_candidates("../gti", ["git"]).is_empty());
    }
}
