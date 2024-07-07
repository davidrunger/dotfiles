# frozen_string_literal: true

# Run these tests with:
#     gal spec/bin/wait_for_gh_checks_spec.rb

load File.expand_path('../../bin/wait-for-gh-checks', __dir__)

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe(WaitForChecksRunner) do
  # rubocop:enable RSpec/SpecFilePathFormat
  subject(:runner) { WaitForChecksRunner.new }

  describe '#repo' do
    subject(:repo) { runner.repo }

    context 'when in the david_runger repo' do
      before { expect(Dir).to receive(:pwd).and_return('/Users/david/code/david_runger') }

      it 'returns "david_runger"' do
        expect(repo).to eq('david_runger')
      end
    end
  end

  describe WaitForChecksRunner::LoopRunner do
    subject(:loop_runner) do
      WaitForChecksRunner::LoopRunner.new(
        runner:,
        printer:,
      )
    end

    let(:printer) { Printer.new }
    let(:runner) { WaitForChecksRunner.new }

    describe '#fail_exit_reason' do
      subject(:fail_exit_reason) { loop_runner.send(:fail_exit_reason) }

      context 'when the test output indicates that the test suite has failed' do
        before do
          expect(loop_runner).
            to receive(:`).
            with(/\Agh pr checks/).
            and_return(<<~GH_RESPONSE)
              IN_PROGRESS
              IN_PROGRESS
              FAILURE
            GH_RESPONSE
        end

        it 'returns "tests failed"' do
          expect(fail_exit_reason).to eq('tests failed')
        end
      end

      context 'when more than 8 minutes have elapsed since the loop runner was initialized' do
        before do
          loop_runner # initialize the loop runner with the real current time
          Timecop.freeze(Time.current + (8.minutes + 1.second))
        end

        it 'returns "max time exceeded"' do
          expect(fail_exit_reason).to eq('max time exceeded')
        end
      end
    end

    describe '#num_passing_checks' do
      subject(:num_passing_checks) { loop_runner.send(:num_passing_checks) }

      context 'when the test output indicates that there are 2 passing checks' do
        before do
          expect(loop_runner).
            to receive(:`).
            with(/\Agh pr checks/).
            and_return(<<~GH_RESPONSE)
              SUCCESS
              SUCCESS
              CANCELLED
            GH_RESPONSE
        end

        it 'returns 2' do
          expect(num_passing_checks).to eq(2)
        end
      end
    end
  end
end
