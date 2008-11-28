
#
# Testing Ruote (OpenWFEru)
#
# John Mettraux at openwfe.org
#
# Thu Nov 27 16:30:23 JST 2008
#

require 'flowtestbase'


class FlowTest93 < Test::Unit::TestCase
  include FlowTestBase

  #
  # TEST 0

  # a block with on_error => 'undo' (or :undo)
  # will simply get undone in case of error

  class Test0 < OpenWFE::ProcessDefinition
    sequence do
      _print '0'
      sequence :on_error => :undo do
        alpha
        _print '1'
      end
      _print '2'
    end
  end

  def test_0

    @engine.register_participant :alpha do |fexp, workitem|
      raise 'houston, we have a problem'
    end

    dotest Test0, "0\n2"
  end

  #
  # TEST 1

  class Test1 < OpenWFE::ProcessDefinition
    sequence do
      _print '0'
      sequence :on_error => 'fail_path' do
        alpha
        _print '1'
      end
      _print '2'
    end
    define 'fail_path' do
      _print 'failed'
    end
  end

  def test_1

    #log_level_to_debug

    @engine.register_participant :alpha do |fexp, workitem|
      raise 'houston, we have a problem'
    end

    dotest Test1, "0\nfailed\n2"
  end
end
