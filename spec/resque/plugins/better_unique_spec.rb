require 'spec_helper'

class TestWorker
  include Resque::Plugins::BetterUnique

  def self.perform(should_be_process_locked)
    raise 'is not process locked' if not locked?(should_be_process_locked) and should_be_process_locked
    raise 'is process locked' if locked?(should_be_process_locked) and not should_be_process_locked
  rescue => e
    puts e.class, e.message, e.backtrace
    raise
  end

  @queue = :test

  def self.queue_key
    'queue:test'
  end

  def self.queue_count
    Resque.redis.llen(queue_key)
  end

  def self.process_from_queue
    worker = Resque::Worker.new(@queue)
    job = worker.reserve
    worker.perform job
  end

  def self.unique_args_function(arg1, arg2)
    arg1
  end
end

describe Resque::Plugins::BetterUnique do
  let(:mode) { :while_executing }
  let(:options) { {} }

  before do
    TestWorker.unique(mode, options)
  end

  describe 'mode' do
    shared_examples_for 'a lock_mode' do

      before do
        Resque.enqueue(TestWorker, should_be_process_locked)
      end

      it "should set the enqueue lock correctly" do
        expected_queue_size = should_be_enqueue_locked ? 1 : 4
        3.times { Resque.enqueue(TestWorker, should_be_process_locked) }
        expect(TestWorker.queue_count).to eq expected_queue_size
      end

      it 'should set the processing lock correctly' do
        expect(TestWorker.process_from_queue).to eq true
      end

      it 'should release the lock afterwards' do
        TestWorker.process_from_queue
        expect(TestWorker.locked?(should_be_process_locked)).to eq should_be_post_process_locked
      end
    end

    context 'while_executing' do
      it_behaves_like 'a lock_mode' do
        let(:mode) { :while_executing }
        let(:should_be_enqueue_locked) { false }
        let(:should_be_process_locked) { true }
        let(:should_be_post_process_locked) { false }
      end
    end

    context 'until_executing' do
      it_behaves_like 'a lock_mode' do
        let(:mode) { :until_executing }
        let(:should_be_enqueue_locked) { true }
        let(:should_be_process_locked) { false }
        let(:should_be_post_process_locked) { false }
      end
    end

    context 'until_executed' do
      it_behaves_like 'a lock_mode' do
        let(:mode) { :until_executed }
        let(:should_be_enqueue_locked) { true }
        let(:should_be_process_locked) { true }
        let(:should_be_post_process_locked) { false }
      end
    end

    context 'until_timeout' do
      it_behaves_like 'a lock_mode' do
        let(:mode) { :until_timeout }
        let(:should_be_enqueue_locked) { true }
        let(:should_be_process_locked) { true }
        let(:should_be_post_process_locked) { true }
      end
    end
  end

  describe '.set_lock' do
    subject { TestWorker.set_lock({args: 1})}

    it 'should set the lock' do
      expect {subject}.to change {TestWorker.locked?({args: 1})}
        .from(false).to(true)
    end

    it { is_expected.to eq true }

    context 'when a lock is set multiple times' do
      it 'should return false when there is already a lock' do
        expect(TestWorker.set_lock({args: 1})).to eq true
        expect(TestWorker.set_lock({args: 1})).to eq false
      end
    end

    context 'timeout' do
      let(:options) { {timeout: 300} }

      it 'should always set the timeout' do
        expect(Resque.redis).to receive(:expire)
        expect(subject).to eq true
      end
    end

    context '.unique_args' do
      let(:options) { {unique_args: unique_args} }

      context 'proc' do
        let(:unique_args) { ->(arg1, arg2) { arg1 }}

        it 'should lock as expected' do
          expect(TestWorker.set_lock(:unique1, :not_unique)).to eq true
          expect(TestWorker.set_lock(:unique2, :not_unique)).to eq true
          expect(TestWorker.set_lock(:unique1, :unique)).to eq false
        end
      end

      context 'method symbol' do
        let(:unique_args) { :unique_args_function }

        it 'should lock as expected' do
          expect(TestWorker.set_lock(:unique1, :not_unique)).to eq true
          expect(TestWorker.set_lock(:unique2, :not_unique)).to eq true
          expect(TestWorker.set_lock(:unique1, :unique)).to eq false
        end
      end
    end
  end

  describe '.release_all_locks' do
    let(:mode) { :until_executed }
    subject { TestWorker.release_all_locks }

    before do
      Resque.redis.set('do_not_remove', true)
      3.times { Resque.enqueue(TestWorker) }
    end

    it 'should clear all locks' do
      expect{subject}.to change{Resque.redis.keys.count}.from(4).to(3)
    end

    context 'with older versions of redis' do
      before do
        allow(Resque.redis).to receive(:scan).and_raise(Redis::CommandError)
      end

      it 'should log an error, but not raise' do
        expect(Resque.logger).to receive(:error)
        expect {subject}.not_to raise_error
      end
    end
  end

end
