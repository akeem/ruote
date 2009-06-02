#--
# Copyright (c) 2005-2009, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'ruote/fei'
require 'ruote/engine/context'
require 'ruote/queue/subscriber'


module Ruote

  #
  # A kind of hub for expression activity (apply/reply and launch + cancel).
  #
  class ExpressionPool

    include EngineContext
    include Subscriber

    # Making sure to observe the work queue once the context is known
    #
    def context= (c)

      @context = c
      subscribe(:expressions)
      subscribe(:processes)
    end

    def reply (workitem)

      wqueue.emit(
        :expressions, :reply,
        :expression => expstorage[workitem.fei], :workitem => workitem)
    end

    #def cancel (fei)
    #  wqueue.emit(:expressions, :cancel, :fei => fei)
    #end
    #def reapply (fei)
    #end

    # This method is called by expressions when applying one of the child
    # expressions.
    #
    def apply_child (exp, child_index, workitem)

      fei = exp.fei.new_child_fei(child_index)

      apply(exp.tree.last[child_index], fei, exp, workitem, nil)
    end

    # Called by expressions when replying to their parent expression.
    #
    def reply_to_parent (exp, workitem)

      wqueue.emit(:expressions, :delete, :fei => exp.fei)
      workitem.fei = exp.fei

      if exp.parent_id

        parent = expstorage[exp.parent_id]

        wqueue.emit(
          :expressions, :reply,
          :expression => parent, :workitem => workitem)

      else

        wqueue.emit(
          :processes, :terminated,
          :wfid => exp.fei.wfid, :workitem => workitem)
      end
    end

    # Called by the subprocess expression when launching a subprocess instance.
    #
    def launch_sub (pos, tree, parent, workitem)

      i = parent.fei.dup
      i.wfid = "#{i.wfid}_#{get_next_sub_id(parent)}"
      i.expid = pos

      apply(tree, i, parent, workitem, {})
    end

    protected

    def get_next_sub_id (parent)

      prefix, last_sub_id = parent.lookup_variable('/__next_sub_id__')

      prefix ||= ''
      last_sub_id ||= -1

      last_sub_id = last_sub_id + 1

      parent.set_variable('/__next_sub_id__', [ prefix, last_sub_id ])

      "#{prefix}#{last_sub_id}"
    end

    def receive (eclass, emsg, eargs)

      if eclass == :expressions

        call_exp(emsg, eargs) if emsg == :apply || emsg == :reply

      elsif eclass == :processes

        launch(eargs) if emsg == :launch

      end
    end

    def call_exp (emsg, eargs)

      begin

        eargs[:expression].send(emsg, eargs[:workitem])

      rescue Exception => e

        # TODO : implement on_error
        #
        #on_error = eargs[:expression].lookup_on(:error)
        #p on_error.collect { |x| x.class }

        wqueue.emit(
          :errors,
          :s_expression_pool,
          { :error => e, :message => [ :expressions, emsg, eargs ] })
      end
    end

    def apply (tree, fei, parent, workitem, variables)

      # NOTE : orphaning will copy vars so parent == nil is OK.

      parent_id = parent ? parent.fei : nil

      exp_name = tree.first

      sub = parent ? parent.lookup_variable(exp_name) : nil
      part = plist.lookup(exp_name)

      if sub or part

        part = [ exp_name, part ] if part

        tree = [
          part ? 'participant' : 'subprocess',
          { 'ref' => part || sub },
          []
        ]

        exp_name = tree.first
      end

      exp_class = expmap.expression_class(exp_name)

      raise "unknown expression '#{exp_name}'" if not exp_class

      exp = exp_class.new(fei, parent_id, tree, variables, workitem)

      wqueue.emit(:expressions, :update, :expression => exp)

      exp.context = @context

      workitem.fei = fei

      wqueue.emit(
        :expressions, :apply,
        :expression => exp, :workitem => workitem)

      fei
    end

    def launch (args)

      fei = new_fei(args[:wfid])

      tree = args[:tree]
      tree = DefineExpression.reorganize(expmap, tree) \
        if expmap.is_definition?(tree)

      apply(tree, fei, nil, args[:workitem], {})
        # {} variables are set here
    end

    def new_fei (wfid)

      fei = FlowExpressionId.new
      fei.engine_id = engine.engine_id
      fei.wfid = wfid || wfidgen.generate
      fei.expid = '0'

      fei
    end
  end
end
