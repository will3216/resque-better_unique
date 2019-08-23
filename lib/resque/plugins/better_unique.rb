module Resque
  module Plugins
    module BetterUnique


      def self.included(base_klass)
        base_klass.extend(ClassMethods)
      end

      module ClassMethods
        # Override in your job to control the lock key. It is
        # passed the same arguments as `perform`, that is, your job's
        # payload.
        def lock_key(*args)
          unique_args = unique_job_options[:unique_args]
          lock_args = case unique_args
          when Proc
            unique_args.call(*args)
          when Symbol
            self.send(unique_args, *args)
          else
            args
          end
          "#{lock_key_base}-#{lock_args.to_s}"
        end

        def lock_key_base
          "lock:#{name}"
        end

        def locked?(*args)
          Resque.redis.exists(lock_key(*args))
        end

        def unique_job_options
          @unique_job_options || {}
        end

        def unique_job_options=(options)
          @unique_job_options = options
        end

        def unique_job_mode
          (unique_job_options[:mode] && unique_job_options[:mode].to_sym) || :none
        end

        # :nocov:
        if RUBY_VERSION =~ /2\.\d+\.\d+/
          def unique_job(mode=:until_executed, **options)
            self.unique_job_options = {mode: mode}.merge(options)
          end
        else
          def unique_job(mode=:until_executed, options={})
            self.unique_job_options = {mode: mode}.merge(options)
          end
        end
        # :nocov:

        def before_enqueue_unique_lock(*args)
          if [:until_executing, :until_executed, :until_timeout].include?(unique_job_mode)
            return false if locked?(*args)
            set_lock(*args)
          end
          true
        end

        def around_perform_unique_lock(*args)
          case unique_job_mode
          when :until_executing
            release_lock(*args)
          when :while_executing
            return if locked?(*args) || !set_lock(*args)
          end
          yield
        ensure
          if [:until_executed, :while_executing].include?(unique_job_mode)
            release_lock(*args)
          end
        end

        def release_lock(*args)
          Resque.redis.del(lock_key(*args))
        end

        def set_lock(*args)
          is_now_locked = Resque.redis.setnx(lock_key(*args), true)
          if is_now_locked && unique_job_options[:timeout]
            Resque.redis.expire(lock_key(*args), unique_job_options[:timeout].to_i)
          end
          is_now_locked
        end

        def release_all_locks(offset=nil)
          return if offset == '0'
          new_offset, keys = Resque.redis.scan(offset || 0)
          keys.each do |key|
            Resque.redis.del(key) if key.start_with?(lock_key_base)
          end
          release_all_locks(new_offset)
        rescue Redis::CommandError
          Resque.logger.error 'This command only works with versions of redis-server over 2.8'
        end
      end
    end
  end
end
