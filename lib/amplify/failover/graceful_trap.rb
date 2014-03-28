# coding: utf-8
module Amplify
  module Failover
    class GracefulTrap
      class << self
        def critical_section(signals = %w(INT TERM QUIT), logger = nil)
          interrupted = false
          received_signal = nil

          signals.each do |signal|
            trap(signal) do
              interrupted = true
              received_signal = signal
              logger.debug("#{signal} received.  Will shut down gracefully...") if logger
            end
          end

          logger.debug('Entering uninterruptible section') if logger
          yield
          logger.debug('Exiting uninterruptible section') if logger
          signals.each do |signal|
            trap(signal, 'DEFAULT')
          end

          # this has to be like this because of
          # https://groups.google.com/forum/#!topic/sinatrarb/Qe441O0a6FU
          # Sinatra handles the SystemExit exception, so it seems to be the
          # only way to kill the app
          if interrupted
            logger.info "Received #{received_signal}." if logger
            Process.kill(received_signal, Process.pid)
          end
        end
      end
    end
  end
end
