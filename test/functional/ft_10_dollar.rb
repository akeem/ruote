
#
# testing ruote
#
# Wed Jun 10 22:57:18 JST 2009
#

require File.join(File.dirname(__FILE__), 'base')


class FtDollarTest < Test::Unit::TestCase
  include FunctionalBase

  def test_default

    pdef = Ruote.process_definition do
      sequence do
        set :var => 'x', :val => 'variable'
        set :field => 'x', :val => 'field'
        echo '${x}'
      end
    end

    #noisy

    assert_trace 'field', pdef
  end

  def test_v

    pdef = Ruote.process_definition do
      sequence do
        echo 'a${v:missing}'
        set :var => 'v0', :val => '0'
        echo 'b${v:v0}'
        echo 'c${var:v0}'
        echo 'd${variable:v0}'
      end
    end

    #noisy

    assert_trace(%w[ a b0 c0 d0 ], pdef)
  end

  def test_nested_v

    pdef = Ruote.process_definition do
      sequence do
        set(
          :var => 'v0',
          :val => {
            'name' => 'toto',
            'address' => [ 'e-street', 'atlantic_city' ] })
        echo 'a:${v:v0.name}'
        echo 'b:${v:v0.address.1}'
      end
    end

    #noisy

    assert_trace(%w[ a:toto b:atlantic_city ], pdef)
  end

  def test_f

    pdef = Ruote.process_definition do
      sequence do
        set :field => 'f', :val => { 'name' => 'toto', 'address' => %w[ KL Asia ]}
        echo 'a${f:missing}'
        echo 'b${f:f.name}'
        echo 'c${f:f.address.1}'
      end
    end

    #noisy

    assert_trace(%w[ a btoto cAsia ], pdef)
  end

  def test_no_r

    pdef = Ruote.process_definition do
      sequence do
        echo '>${r:1 + 2}<'
      end
    end

    #noisy

    wfid = @engine.launch(pdef)

    @engine.wait_for(wfid)

    assert_equal(
      "#<ArgumentError: 'ruby_eval_allowed' is set to false, cannot evaluate" +
      " >1 + 2< (http://ruote.rubyforge.org/dollar.html)>",
      @engine.errors.first.message)
  end

  def test_r

    pdef = Ruote.process_definition do
      sequence do
        echo '>${r:1 + 2}<'
      end
    end

    #noisy

    @engine.context['ruby_eval_allowed'] = true

    assert_trace('>3<', pdef)
  end

  def test_r_and_wi

    pdef = Ruote.process_definition do
      sequence do
        set 'f:toto' => 'person'
        echo "${r:wi.fields['toto']}"
        echo "${r:workitem.fields['toto']}"
      end
    end

    #noisy

    @engine.context['ruby_eval_allowed'] = true

    assert_trace "person\nperson", pdef
  end

  def test_r_and_d

    pdef = Ruote.process_definition do
      sequence do
        set 'f:toto' => 'person'
        echo "${r:d('f:toto')}"
      end
    end

    #noisy

    @engine.context['ruby_eval_allowed'] = true

    assert_trace 'person', pdef
  end

  def test_nested

    pdef = Ruote.process_definition do
      sequence do
        set 'f:a' => 'a'
        set 'v:a' => 'AA'
        echo '${v:${f:a}}'
      end
    end

    #noisy

    assert_trace 'AA', pdef
  end

  def test_fei_and_wfid

    pdef = Ruote.process_definition do
      sequence do
        echo '${fei}'
        echo '${wfid}'
      end
    end

    wfid = @engine.launch(pdef)

    @engine.wait_for(wfid)

    assert_match /^0_0_0![^!]+!#{wfid}\n#{wfid}$/, @tracer.to_s
  end

  def test_direct_access_to_fields

    pdef = Ruote.process_definition do
      sequence do
        set 'f:a' => [ 'alpha', 'bravo', 'charly' ]
        echo '${r:a.join("/")}'
      end
    end

    @engine.context['ruby_eval_allowed'] = true

    #noisy

    assert_trace 'alpha/bravo/charly', pdef
  end

  def test_dollar_quote

    pdef = Ruote.define do
      set 'f:a' => 'alpha'
      set 'f:b' => 'bra vo'
      echo '${"f:a}'
      echo "${'f:a}"
      echo 'ok', :if => "${'f:b} == 'bra vo'"
    end

    assert_trace %w[ "alpha" "alpha" ok ], pdef
  end

  def test_literally

    pdef = Ruote.define do
      set 'f:a' => %w[ A B C ]
      set 'f:b' => 'a'
      set 'v:c' => %w[ venture capitalist ]
      set 'f:A' => '$f:a'
      set 'f:B' => '$f:${b}'
      set 'f:C' => '$v:c'
      set 'f:D' => '$f:nada'
      set 'f:E' => '$v:nada'
      set 'f:F' => '$a'
      set 'f:G' => '$nada'
      set 'f:H' => '$a '
      filter :f => /^[a-c]$/, :del => true
    end

    #noisy

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(wfid)

    assert_equal(
      {
        'A' => %w[ A B C ],
        'B' => %w[ A B C ],
        'C' => %w[ venture capitalist ],
        'D' => '$f:nada',
        'E' => '$v:nada',
        'F' => %w[ A B C ],
        'G' => '$nada',
        'H' => '$a '
      },
      r['workitem']['fields'])
  end

  def test_literally_and_participant_params

    pdef = Ruote.define do
      set 'f:a' => %w[ A B C ]
      alpha :b => '$f:a'
    end

    @engine.register_participant :alpha do |wi|
      wi.fields['parameters'] = wi.fields['params']
    end

    #noisy

    wfid = @engine.launch(pdef)

    r = @engine.wait_for(wfid)

    assert_equal(
      { 'b' => %w[ A B C ], 'ref' => 'alpha' },
      r['workitem']['fields']['parameters'])
  end

  # Issue pointed out by John Le.
  #
  def test_not_a_number

    pdef = Ruote.define do
      echo 'a0', :if => '${a}'
      echo 'a1', :if => '${a} is set'
      echo 'b', :if => '${b}'
      echo 'c'
    end

    wfid = @engine.launch(
      pdef,
      'a' => '0a')

    @engine.wait_for(wfid)

    assert_equal "a0\na1\nc", @tracer.to_s
  end

  def test_literal

    pdef = Ruote.define do
      set 'f:a' => true
      _if '$a' do
        echo 'a0'
      end
      echo 'a1', :if => '$a'
    end

    wfid = @engine.launch(pdef)
    @engine.wait_for(wfid)

    assert_equal "a0\na1", @tracer.to_s
  end
end

