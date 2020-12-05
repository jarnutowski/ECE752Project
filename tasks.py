"""
Tasks for maintaining the project.

Execute 'invoke --list' for guidance on using Invoke
"""
import os
import glob
import shutil
import platform
from pathlib import Path

from invoke import task


ROOT_DIR = Path(__file__).parent
TEST_PATHS = [f'{ROOT_DIR}/gem5-resources/src/square/', ]


def _delete_file(file):
    if os.path.isfile(file):
        print(f"Removing file {file}...")
        os.remove(file)
    elif os.path.isdir(file):
        print(f"Removing directory {file}...")
        shutil.rmtree(file, ignore_errors=True)


def _delete_pattern(pattern):
    for file in glob.glob(os.path.join("**", pattern), recursive=True):
        _delete_file(file)


def _run(c, command):
    return c.run(command, pty=platform.system() != "Windows")


@task
def clean_gem5(c):
    _delete_file(f'{ROOT_DIR}/gem5/build/')


@task
def clean_python(c):
    """Clean up python file artifacts"""
    _delete_pattern("__pycache__")
    _delete_pattern("*.pyc")
    _delete_pattern("*.pyo")
    _delete_pattern("*~")


@task
def clean_tests(c):
    """Clean compiled tests such as square"""
    for test_path in TEST_PATHS:
        _run(c, f'cd {test_path} && make clean')


@task(pre=[clean_gem5, clean_python, clean_tests])
def clean(c):
    """Runs all clean sub-tasks"""


@task
def build_gem5(c):
    """Build all of gem5 GCN3"""
    _run(c, 'cd gem5/ && scons -j$(nproc) ./build/GCN3_X86/gem5.opt')        


@task
def build_tests(c):
    """Build all tests"""
    for test_path in TEST_PATHS:
        _run(c, f'cd {test_path} && make')


@task(pre=[build_gem5, build_tests])
def build(c):
    """Runs all build sub-tasks"""

