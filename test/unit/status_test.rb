require File.dirname(__FILE__) + '/../test_helper'

class StatusTest < Test::Unit::TestCase
  fixtures :statuses

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Status, statuses(:first)
  end
end
