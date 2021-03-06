
#
# testing ruote
#
# Wed Apr  6 06:52:53 JST 2011
#
# Santa Barbara
#

require File.join(File.dirname(__FILE__), 'base')

require 'ruote'
#require 'ruote/participant'


class FtRevParticipantTest < Test::Unit::TestCase
  include FunctionalBase

  def test_consume

    dir = compute_dir_name

    FileUtils.mkdir(dir)

    File.open(dir + '/alpha.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  (workitem.fields['seen'] ||= []) << 'alpha'
  reply_to_engine(workitem)
end
      })
    end
    File.open(dir + '/alpha__z.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  (workitem.fields['seen'] ||= []) << 'alpha__z'
  reply_to_engine(workitem)
end
      })
    end

    @engine.register do
      catchall Ruote::RevParticipant, :dir => dir
    end

    pdef = Ruote.process_definition 'x', :revision => 'y' do
      alpha :rev => 'z'
      alpha
    end

    #@engine.noisy = true

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(wfid)

    assert_equal %w[ alpha__z alpha ], r['workitem']['fields']['seen']

  ensure
    FileUtils.rm_rf(dir)
  end

  def test_cancel

    dir = compute_dir_name

    FileUtils.mkdir(dir)

    $seen = false

    File.open(dir + '/alpha.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  # do nothing
end
def cancel(fei, flavour)
  $seen = true
end
      })
    end

    @engine.register do
      catchall Ruote::RevParticipant, :dir => dir
    end

    pdef = Ruote.process_definition do
      alpha
    end

    #@engine.noisy = true

    wfid = @engine.launch(pdef)

    @engine.wait_for(:alpha)

    assert_equal false, $seen

    @engine.cancel(wfid)

    @engine.wait_for(wfid)

    assert_equal true, $seen

  ensure
    FileUtils.rm_rf(dir)
  end

  def test_accept

    dir = compute_dir_name

    FileUtils.mkdir(dir)

    File.open(dir + '/alpha.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  (workitem.fields['seen'] ||= []) << 'alpha'
  reply_to_engine(workitem)
end
      })
    end
    File.open(dir + '/alpha__z.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  raise "I should never get raised !"
end
def accept?(workitem)
  false
end
      })
    end

    @engine.register do
      catchall Ruote::RevParticipant, :dir => dir
    end

    pdef = Ruote.process_definition do
      alpha :rev => 'z'
    end

    #@engine.noisy = true

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(wfid)

    assert_equal %w[ alpha ], r['workitem']['fields']['seen']

  ensure
    FileUtils.rm_rf(dir)
  end

  def test_on_reply

    dir = compute_dir_name

    FileUtils.mkdir(dir)

    File.open(dir + '/alpha.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  reply_to_engine(workitem)
end
def on_reply(workitem)
  (workitem.fields['seen'] ||= []) << 'on_reply'
end
      })
    end

    @engine.register do
      catchall Ruote::RevParticipant, :dir => dir
    end

    pdef = Ruote.process_definition do
      alpha
    end

    #@engine.noisy = true

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(wfid)

    assert_equal %w[ on_reply ], r['workitem']['fields']['seen']

  ensure
    FileUtils.rm_rf(dir)
  end

  def test_rtimeout

    dir = compute_dir_name

    FileUtils.mkdir(dir)

    File.open(dir + '/alpha.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  #reply_to_engine(workitem)
end
      })
    end
    File.open(dir + '/bravo.rb', 'wb') do |f|
      f.write(%{
def consume(workitem)
  #reply_to_engine(workitem)
end
def rtimeout(workitem)
  '2d'
end
      })
    end

    @engine.register do
      catchall Ruote::RevParticipant, :dir => dir
    end

    pdef = Ruote.process_definition do
      alpha
      bravo
    end

    #@engine.noisy = true

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(:alpha)
    sleep 0.350

    assert_equal 0, @engine.storage.get_many('schedules').size

    wi = @engine.ps(wfid).workitems.first

    @engine.receive(wi)

    r = @engine.wait_for(:bravo)
    sleep 0.350

    assert_equal 1, @engine.storage.get_many('schedules').size

  ensure
    FileUtils.rm_rf(dir)
  end

  protected

  def compute_dir_name

    [ 'rev_participant', $$, Time.now.to_f ].collect { |e| e.to_s }.join('_')
  end
end

