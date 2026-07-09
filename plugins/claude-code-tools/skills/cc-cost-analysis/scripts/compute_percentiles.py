#!/usr/bin/env python3
# requires Python 3.10+ (uses list[float] type hints)
"""Compute percentiles from a list of per-user values.

Usage:
  echo '{"values": [1.5, 3.2, 10.0, 25.4, 8.1]}' | python3 compute_percentiles.py

  OR with a column name to extract from a Honeycomb result set:
  echo '<json_rows>' | python3 compute_percentiles.py --column total_cost

The input should be a JSON object with a "values" key containing a list of numbers,
or a JSON array of objects when --column is specified.
"""

import json
import math
import sys
import argparse


def percentile(sorted_values: list[float], pct: float) -> float:
    n = len(sorted_values)
    if n == 0:
        raise ValueError("No values to compute percentiles from")
    # Nearest-rank method: ceil(n * pct / 100), clamped to valid range
    idx = max(0, min(n - 1, math.ceil(n * pct / 100) - 1))
    return sorted_values[idx]


def main():
    parser = argparse.ArgumentParser(description="Compute percentiles from Honeycomb query results")
    parser.add_argument("--column", help="Column name to extract from JSON row objects")
    parser.add_argument("--exclude-zero", action=argparse.BooleanOptionalAction, default=True,
                        help="Exclude zero/null values (default: True). Use --no-exclude-zero to include zeros.")
    args = parser.parse_args()

    data = json.load(sys.stdin)

    def to_float(v) -> float | None:
        """Convert a value to float, returning None for non-numeric values.
        Honeycomb returns the string "null" for missing values, not Python None."""
        if v is None or v == "null":
            return None
        try:
            return float(v)
        except (ValueError, TypeError):
            return None

    if args.column:
        # run_query response wraps rows in a "results" key; also accept bare list
        rows = data if isinstance(data, list) else data.get("results", data.get("values", []))
        values = [
            f for row in rows
            if (f := to_float(row.get(args.column))) is not None
            and (not args.exclude_zero or f > 0)
        ]
    else:
        # Accept both "results" (run_query response) and "values" (direct input)
        raw = data.get("results", data.get("values", []))
        values = [f for v in raw if (f := to_float(v)) is not None and (not args.exclude_zero or f > 0)]

    if not values:
        print(json.dumps({"error": "No values after filtering"}))
        sys.exit(1)

    values.sort()
    n = len(values)

    result = {
        "n": n,
        "min": values[0],
        "p10": percentile(values, 10),
        "p25": percentile(values, 25),
        "p50": percentile(values, 50),
        "p75": percentile(values, 75),
        "p90": percentile(values, 90),
        "p99": percentile(values, 99),
        "max": values[-1],
        "mean": sum(values) / n,
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
