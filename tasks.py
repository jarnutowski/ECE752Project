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
from invoke.tasks import call


ROOT_DIR = Path(__file__).parent
with open(f'{ROOT_DIR}/tests.txt', 'r') as f:
    TEST_PATHS = [i.strip() for i in f.read().split('\n') if i.strip()]


def _delete_file(file, verbose=True, indent=''):
    if os.path.isfile(file):
        if verbose:
            print(f"{indent}Removing file {file}...")
        os.remove(file)
    elif os.path.isdir(file):
        if verbose:
            print(f"{indent}Removing directory {file}...")
        shutil.rmtree(file, ignore_errors=True)


def _delete_pattern(pattern, **kwargs):
    for file in glob.glob(os.path.join("**", pattern), recursive=True):
        _delete_file(file, **kwargs)


def _run(c, command, **kwargs):
    return c.run(command, pty=platform.system() != "Windows", **kwargs)


@task
def clean_gem5(c):
    """Remove build directory of gem5"""
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
        print(f'Running `make clean` for {test_path}...')
        _run(c, f'cd {test_path} && make clean', hide='out')


@task
def clean_condor(c):
    """Clean condor files (log, err, out, ...)"""
    for fname in glob.glob(os.path.join(ROOT_DIR, '*.dag')):
        _delete_pattern(fname + '.*')
    for fname in glob.glob(os.path.join(ROOT_DIR, '*.sub')):
        temps = []
        with open(fname, 'r') as f:
            for line in f.readlines():
                for w in ('log', 'error', 'output'):
                    if line.startswith(w):
                        temp = line.split('=')[-1].strip()
                        if os.path.isfile(temp):
                            temps.append(temp)
        if temps:
            print(f'Found submit script {fname}:')
            for temp in temps:
                _delete_file(temp, indent='  ')
    _delete_file(f'{ROOT_DIR}/docker_stderror')
    _delete_file(f'{ROOT_DIR}/parsetab.py')


@task(pre=[clean_gem5, clean_python, clean_tests, clean_condor])
def clean(c):
    """Runs all clean sub-tasks"""


@task
def build_gem5(c, archive=False):
    """Build all of gem5 GCN3"""
    _run(c, f'cd {ROOT_DIR}/gem5/ && scons -j$(nproc) ./build/GCN3_X86/gem5.opt')    
    if archive:    
        _run(c, f'tar -czf gem5-build.tar gem5/build/')

@task
def build_tests(c, archive=False):
    """Build all tests"""
    for test_path in TEST_PATHS:
        _run(c, f'cd {test_path} && make')
    if archive:
        for i, test_paths in enumerate(TEST_PATHS):
            _run(c, f'tar -czf bin-{i}.tar {test_path}/bin/')


@task(pre=[call(build_gem5, archive=True), call(build_tests, archive=True)])
def build(c):
    """Runs all build sub-tasks"""


@task
def test_square(c):
    """Run the square test"""
    exec_path = f'{ROOT_DIR}/gem5/build/GCN3_X86/gem5.opt' 
    conf_path = f'{ROOT_DIR}/gem5/configs/example/apu_se.py'
    args = f'-n 2 --benchmark-root={ROOT_DIR}/gem5-resources/src/square/bin -c square.o'
    _run(c, ' '.join([exec_path, conf_path, args]))



