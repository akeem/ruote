#--
# Copyright (c) 2005-2011, John Mettraux, jmettraux@gmail.com
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

require 'ruote/log/test_logger'


module Ruote

  #
  # A helper logger for quickstart examples.
  #
  # Keeps a maximum of 147 messages.
  #
  class WaitLogger < TestLogger

    attr_accessor :noisy

    def initialize(context)

      @context = context
      @color = 33

      @context.worker.subscribe(:all, self) if @context.worker

      @noisy = false
      @count = -1

      @seen = []
      @waiting = []
    end

    def notify(msg)

      puts(fancy_print(msg)) if @noisy

      @seen << msg if msg['action'] != 'noop'
      @seen.shift if @seen.size > 147

      check_waiting
    end
  end
end

