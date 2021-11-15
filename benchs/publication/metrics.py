#!/usr/bin/env python3
import os
from typing import Dict

import git


class Metric:

    def __init__(self, benchmark: str, values: Dict) -> None:
        """Provide basic tags for describing metric.

        Mostly common tags are benchmark name, commit, branch, timestamp.
        """
        self.path_to_repo = os.getenv("GITHUB_WORKSPACE")
        self.repo = git.Repo(self.path_to_repo)
        self.benchmark = benchmark
        self.branch = self.repo.active_branch
        self.commit = self.repo.head.commit
        self.values = ",".join(
            [f"{label}={value}" for label, value in values.items()])

        # TODO: use commit timestamp as a basic time value. default value
        # is provided by database as a time when value is posted.
        # It is important for retrospective.
        self.timestamp = self.commit.committed_date

    def __str__(self) -> str:
        """Represent metric in prometheus format to make POST request."""
        return f"perf,benchmark={self.benchmark},branch={self.branch}" \
               f" {self.values}"
