# Copyright 2018 D-Wave Systems Inc.
# Author: William Bernoudy (wbernoudy@dwavesys.com)

from __future__ import print_function
import sys
import os
import warnings

if sys.version_info[0] == 2:
    range = xrange
    iteritems = lambda d: d.iteritems()
else:
    iteritems = lambda d: d.items()

class PreprocessParseError(Exception):
    pass

class ForLoopParseError(PreprocessParseError):
    pass

def insert_compile_constants(lines, compile_constants):
    pp_lines = []
    for line in lines:
        for const, val in iteritems(compile_constants):
            line = line.replace(const, str(val))
        pp_lines.append(line)
    return pp_lines


def preprocess_cuda(file_name, compile_constants):
    start_macro = "START_PYTHON_PREPROCESS"
    end_macro = "END_PYTHON_PREPROCESS"

    with open(file_name, "r") as f:
        lines = f.read().splitlines()

    lines = insert_compile_constants(lines, compile_constants)

    def expand_for(code, start_line_idx):
        tokens = code[0].split(" ")
        if len(tokens) != 6:
            raise ForLoopParseError(("for loop start line has wrong number of "
                                     "tokens: got {}, expected 6").format(
                                         len(tokens)))
        var_name = tokens[1]
        start, end = int(tokens[3]), int(tokens[5])
        if end - start > 1000:
            raise ForLoopParseError("for loop has range larger than 1000")

        body_lines = code[1:-1]
        if sum(bl.count(var_name) for bl in body_lines) == 0:
            warnings.warn(("`{}` was only found once in for loop body at "
                           "line {}").format(var_name, start_line_idx))

        parsed_lines = []

        for i in range(start, end):
            for l in body_lines:
                parsed_lines.append(l.replace(var_name, str(i)))
        return parsed_lines

    pp_lines = []
    pp_offset = 0
    start_line_idx = 0
    while start_line_idx < len(lines):
        if start_macro not in lines[start_line_idx]:
            pp_lines.append(lines[start_line_idx])
            start_line_idx += 1
            continue

        pp_code = []
        line_idx = start_line_idx + 1

        while end_macro not in lines[line_idx]:
            pp_code.append(lines[line_idx].strip())
            line_idx += 1
            if line_idx == len(lines):
                raise PreprocessParseError("could not find terminating preprocessor after start on line {}".format(start_line_idx))


        if pp_code[0].strip()[:3] == "for" and pp_code[-1].strip() == "endfor":
            insert_lines = expand_for(pp_code, start_line_idx)
        else:
            print(pp_code)
            raise PreprocessParseError("could not parse preprocessor code")

        end_line_idx = line_idx
        # pp_lines[end_line_idx:end_line_idx] = insert_lines
        pp_lines.extend(insert_lines)
        pp_offset += len(insert_lines)

        start_line_idx = end_line_idx + 1

    return pp_lines

class UsageError(Exception):
    """Basic exception for errors raised by cars"""
    def __init__(self, msg=None):
        if msg is None:
            msg = "Usage: python preprocessor.py file0 file1 [N]"
        super(UsageError, self).__init__(msg)

if __name__ == "__main__":
    N = 150

    if len(sys.argv) < 2 or len(sys.argv) > 4:
        raise UsageError()

    N = 150 # default
    input_filename, output_filename = sys.argv[1:3]
    if len(sys.argv) == 4:
        N = int(sys.argv[3])

    print("Compiling for N={}".format(N))

    output_lines = preprocess_cuda(input_filename, {"__N__": N})

    with open(output_filename, "w") as f:
        f.write("\n".join(output_lines))
