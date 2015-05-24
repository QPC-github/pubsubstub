module Pubsubstub
  class RedisPubSub
    def initialize(channel_name)
      @channel_name = channel_name
    end

    def subscribe(callback)
      self.class.sub.subscribe(key('pubsub'), callback)
    end

    def unsubscribe(callback)
      self.class.sub.unsubscribe_proc(key('pubsub'), callback)
    end

    def publish(event)
      self.class.publish(@channel_name, event)
    end

    def scrollback(since_event_id)
      redis = if EventMachine.reactor_running?
        self.class.nonblocking_redis
      else
        self.class.blocking_redis
      end

      redis.zrangebyscore(key('scrollback'), "(#{since_event_id.to_i}", '+inf') do |events|
        events.each do |json|
          yield Pubsubstub::Event.from_json(json)
        end
      end
    end

    private

    def key(purpose)
      [@channel_name, purpose].join(".")
    end

    class << self
      def publish(channel_name, event)
        blocking_redis.publish("#{channel_name}.pubsub", event.to_json)
        blocking_redis.zadd("#{channel_name}.scrollback", event.id, event.to_json)
      end

      def sub
        @sub ||= nonblocking_redis.pubsub
      end

      def blocking_redis
        @blocking_redis ||= Redis.new(url: redis_url)
      end

      def nonblocking_redis
        @nonblocking_redis ||= EM::Hiredis.connect(redis_url)
      end

      def redis_url
        ENV['REDIS_URL'] || "redis://localhost:6379"
      end
    end
  end
end
