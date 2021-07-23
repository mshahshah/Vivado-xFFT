#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TOOL_DIR=$SCRIPT_DIR/..


# Setup the Python virtual environment
if [ ! -d $TOOL_DIR/venv ]; then
    python3 -m venv $TOOL_DIR/venv
    source $TOOL_DIR/venv/bin/activate
    pip install --upgrade pip
    pip install numpy
    pip install matplotlib
    pip install pandas
    pip install pyyaml
    pip install scipy

    source $TOOL_DIR/venv/bin/activate
else
    source $TOOL_DIR/venv/bin/activate
    # add otehr python packages here
fi

