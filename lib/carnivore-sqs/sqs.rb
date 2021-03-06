require 'fog'
require 'carnivore/source'

module Carnivore
  class Source
    class Sqs < Source

      OUTPUT_REPEAT_EVERY=20

      attr_reader :pause_time

      def setup(args={})
        @fog = nil
        @connection_args = args[:fog]
        case args[:queues]
        when Hash
          @queues = args[:queues]
        else
          @queues = Array(args[:queues]).flatten.compact
          @queues = Hash[*(
              @queues.size.times.map(&:to_i).zip(@queues).flatten
          )]
        end
        @queues = Hash[
          @queues.map do |k,v|
            [k, format_queue(v)]
          end
        ]
        if(args[:processable_queues])
          @processable_queues = Array(args[:processable_queues]).flatten.compact
        end
        @pause_time = args[:pause] || 5
        debug "Setup for SQS source instance <#{name}> complete"
        debug "Configured queues for handling: #{@queues.inspect}"
      end

      def format_queue(q)
        unless(q.include?('.com'))
          if((parts = q.split(':')).size > 1)
            "/#{parts[-2,2].join('/')}"
          else
            q
          end
        else
          q
        end
      end

      def connect
        @fog = Fog::AWS::SQS.new(@connection_args)
        debug "Connection for SQS source instance <#{name}> is now complete"
      end

      def receive(n=1)
        count = 0
        msgs = []
        while(msgs.empty?)
          msgs = []
          msgs = queues.map do |q|
            begin
              defer do
                Timeout.timeout(args.fetch(:receive_timeout, 30).to_i) do
                  m = @fog.receive_message(q, 'MaxNumberOfMessages' => n, 'WaitTimeSeconds' => 25).body['Message']
                  m.map{|mg| mg.merge('SourceQueue' => q)}
                end
              end
            rescue Timeout::Error
              error 'Receive timeout encountered. Triggering a reconnection.'
              connect
              retry
            rescue Excon::Errors::Error => e
              error "SQS received an unexpected error. Pausing and running retry (#{e.class}: #{e})"
              debug "SQS ERROR TRACE: #{e.class}: #{e}\n#{e.backtrace.join("\n")}"
              sleep Carnivore::Config.get(:carnivore, :sqs, :retry_wait) || 5
              retry
            end
          end.flatten.compact
          if(msgs.empty?)
            if(count == 0)
              debug "Source<#{name}> no message received. Sleeping for #{pause_time} seconds."
            elsif(count % OUTPUT_REPEAT_EVERY == 0)
              debug "Source<#{name}> last message repeated #{count} times"
            end
            sleep(pause_time)
          else
            debug "Received: #{msgs.inspect}"
          end
          count += 1
        end
        msgs.flatten.compact.map{|m| pre_process(m) }
      end

      def transmit(message, original=nil)
        begin
          queue = determine_queue(original)
          message = JSON.dump(message) unless message.is_a?(String)
          defer{ @fog.send_message(queue, message) }
        rescue Excon::Errors::Error => e
          error "SQS transmission received an unexpected error. Pausing and running retry (#{e.class}: #{e})"
          debug "SQS ERROR TRACE: #{e.class}: #{e}\n#{e.backtrace.join("\n")}"
          sleep Carnivore::Config.get(:carnivore, :sqs, :retry_wait) || 5
          retry
        end
      end

      def touch(message)
        begin
          queue = determine_queue(message)
          debug "Source<#{name}> Touching message<#{message}> on Queue<#{queue}>"
          m = message.is_a?(Message) ? message[:message] : message
          if(m['ReceiptHandle'])
            @fog.change_message_visibility(queue, m['ReceiptHandle'], 30)
          else
            debug "Message contained no receipt handle. Likely a looper #{message}"
          end
        rescue => e
          error "Failed to touch message to reset timeout! #{message} - #{e.class}: #{e}"
        end
      end

      def confirm(message)
        queue = determine_queue(message)
        debug "Source<#{name}> Confirming message<#{message}> on Queue<#{queue}>"
        m = message.is_a?(Message) ? message[:message] : message
        if(m['ReceiptHandle'])
          @fog.delete_message(queue, m['ReceiptHandle'])
        else
          debug "Message contained no receipt handle. Likely a looper #{message}"
        end
      end

      private

      def determine_queue(obj)
        queue = nil
        if(obj)
          if(obj.is_a?(Message))
            queue = obj[:message]['SourceQueue']
          else
            case obj
            when Numeric
              queue = @queues[dest]
            when String, Symbol
              queue = @queues[dest.to_s] || queues.detect{|q| q.end_with?(dest.to_s)}
            when Hash
              queue = obj['SourceQueue']
            end
          end
        end
        queue || queues.first
      end

      def queues
        if(@processable_queues)
          @queues.map do |k,v|
            v if @processable_queues.include?(k)
          end.compact
        else
          @queues.values
        end
      end

      def fog
        unless(@fog)
          connect
        end
        @fog
      end

      def pre_process(msg)
        if(msg['Body'])
          begin
            msg['Body'] = JSON.load(msg['Body'])
          rescue JSON::ParserError
            # well, we did our best
          end
        end
        Smash.new(
          :raw => msg,
          :content => msg['Body']
        )
      end

    end
  end
end
