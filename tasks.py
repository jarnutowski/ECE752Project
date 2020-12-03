"""
Tasks for maintaining the project.

Execute 'invoke --list' for guidance on using Invoke
"""
import os
import glob
import shutil
import platform

from invoke import task
from pathlib import Path


ROOT_DIR = Path(__file__).parent

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
def clean_python(c):
    """Clean up python file artifacts"""
    _delete_pattern("__pycache__")
    _delete_pattern("*.pyc")
    _delete_pattern("*.pyo")
    _delete_pattern("*~")
