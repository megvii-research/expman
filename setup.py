#!/usr/bin/env python3
import os
from datetime import datetime

import setuptools
from setuptools import setup


def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()


setup(
    name="exbranch",
    version="0.4.0.1",
    author="Yuzhi Wang",
    author_email="wangyuzhi@megvii.com",
    description=("Handy tool for git-worktree"),
    license="Apache 2.0",
    packages=[],
    long_description="This is a dummy package, visit <https://github.com/megvii-research/exbranch> for more infomation",
    include_package_data=False,
)

# vim: ts=4 sw=4 sts=4 expandtab
