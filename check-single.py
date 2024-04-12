
#!python3

import sys
import os
import argparse
from colorama import Fore, Back, Style

parser = argparse.ArgumentParser(description='Check gcc testsuite result.')
parser.add_argument ("--summary_file", type=str, required=True)
parser.add_argument ("--golden_file", type=str, required=True)

args = parser.parse_args()

uncertain_fail_list = [
#   "FAIL: c-c++-common/builtins.c  -Wc++-compat  (test for excess errors)\n",
#   "FAIL: gcc.dg/cpp/_Pragma3.c (test for excess errors)\n"
]

def get_test_summary(log_file):
  with open(log_file, "r") as file:
    is_summary = False
    summary = set ()
    fail_list = set ()
    xpass_list = set ()
    unresolved_list = set ()
    unsupported_list = set ()
    error_list = set ()
    line = file.readline()
    while line:
      #print (log_file, line)
      if line.startswith('FAIL: '):
        fail_list.add(line)
      elif line.startswith('XPASS: '):
        xpass_list.add(line)
      elif line.startswith('UNRESOLVED: '):
        unresolved_list.add(line)
      elif line.startswith('UNSUPPORTED: '):
        unsupported_list.add(line)
      elif line.startswith('ERROR: '):
        error_list.add(line)
      if "=== gcc Summary ===" in line:
        is_summary = True
      if is_summary:
        summary.add(line)
      try:
        line = file.readline()
      except Exception as e:
        print (e, line)
    return {
      "error_list": error_list,
      "fail_list": fail_list,
      "xpass_list": xpass_list,
      "unresolved_list": unresolved_list,
      "unsupported_list": unsupported_list,
      "summary": summary,
    }

def check_test_summary(summary, golden):
  golden_fail_list = golden["fail_list"]
  summary_fail_list = summary["fail_list"]
  current_uncertain_fail_list = []
  for fail in summary_fail_list.copy():
    if fail in golden_fail_list:
      summary_fail_list.remove(fail)
      golden_fail_list.remove(fail)
    elif fail in uncertain_fail_list:
      summary_fail_list.remove(fail)
      current_uncertain_fail_list.add(fail)

  golden_xpass_list = golden["xpass_list"]
  summary_xpass_list = summary["xpass_list"]
  for xpass in summary_xpass_list.copy():
    if xpass in golden_xpass_list:
      golden_xpass_list.remove(xpass)
      summary_xpass_list.remove(xpass)

  golden_unresolved_list = golden["unresolved_list"]
  summary_unresolved_list = summary["unresolved_list"]
  for unresolved in golden_unresolved_list.copy():
    if unresolved in summary_unresolved_list:
      golden_unresolved_list.remove(unresolved)
      summary_unresolved_list.remove(unresolved)

  golden_unsupported_list = golden["unsupported_list"]
  summary_unsupported_list = summary["unsupported_list"]
  for unsupported in golden_unsupported_list.copy():
    if unsupported in summary_unsupported_list:
      golden_unsupported_list.remove(unsupported)
      summary_unsupported_list.remove(unsupported)

  golden_error_list = golden["error_list"]
  summary_error_list = summary["error_list"]
  for error in golden_error_list.copy():
    if error in summary_error_list:
      golden_error_list.remove(error)
      summary_error_list.remove(error)

  has_diff = len(
    summary_fail_list | golden_fail_list |
    summary_xpass_list | golden_xpass_list |
    summary_unresolved_list | golden_unresolved_list |
    summary_unsupported_list | golden_unsupported_list |
    summary_error_list | summary_error_list
  ) > 0

  return {
    "has_diff": has_diff,
    "increased_fail_list": summary_fail_list,
    "reduced_fail_list": golden_fail_list,
    "increased_xpass_list": summary_xpass_list,
    "reduced_xpass_list": golden_xpass_list,
    "increased_unresolved_list": summary_unresolved_list,
    "reduced_unresolved_list": golden_unresolved_list,
    "increased_unsupported_list": summary_unsupported_list,
    "reduced_unsupported_list": golden_unsupported_list,
    "increased_error_list": summary_error_list,
    "reduced_error_list": golden_error_list,
    "uncertain_fail_list": current_uncertain_fail_list
  }

def print_diff_list(color, diff_list, list_name):
  if len(diff_list[list_name]) > 0:
    print("{}:".format(list_name.replace("_", " ").upper()))
    print(color + "".join(diff_list[list_name]))
    print(Style.RESET_ALL)

def print_test_summary(summary_file, golden_file):
  summary = get_test_summary(summary_file)
  golden = get_test_summary(golden_file)
  title = os.path.basename(summary_file).replace(".sum", "").upper()

  diff = check_test_summary(summary, golden)
  if (diff["has_diff"]):
    print("=== Test Diff ===\n")

    print_diff_list(Fore.RED, diff, "increased_fail_list")
    print_diff_list(Fore.RED, diff, "increased_xpass_list")
    print_diff_list(Fore.RED, diff, "increased_unresolved_list")
    print_diff_list(Fore.RED, diff, "increased_unsupported_list")
    print_diff_list(Fore.RED, diff, "increased_error_list")

    print_diff_list(Fore.GREEN, diff, "reduced_fail_list")
    print_diff_list(Fore.GREEN, diff, "reduced_xpass_list")
    print_diff_list(Fore.GREEN, diff, "reduced_unresolved_list")
    print_diff_list(Fore.GREEN, diff, "reduced_unsupported_list")
    print_diff_list(Fore.GREEN, diff, "reduced_error_list")

  print_diff_list(Fore.CYAN, diff, "uncertain_fail_list")

  if diff["has_diff"]:
    print(Fore.RED + ">> {} Test Result Checker Found Difference <<".format(title))
    print(Style.RESET_ALL)
  else:
    print(Fore.GREEN + ">> {} Test Result Checker Pass <<".format(title))
    print(Style.RESET_ALL)

  print("=== Test Summary End ===\n")

print_test_summary(args.summary_file, args.golden_file)
