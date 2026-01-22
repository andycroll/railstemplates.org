require "bundler"
require "minitest/autorun"
require "fileutils"

TEMPLATES_DIR = File.expand_path("../_templates", __dir__)
TMP_DIR = File.expand_path("../tmp/test_apps", __dir__)
