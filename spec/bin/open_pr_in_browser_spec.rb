# frozen_string_literal: true

# Run these tests with:
#     gal spec/bin/open_pr_in_browser_spec.rb

load File.expand_path('../../bin/open-pr-in-browser', __dir__)

RSpec.describe(OpenPrInBrowser) do
  subject(:runner) { OpenPrInBrowser.new(create_pr_command_output) }

  describe '#pr_link' do
    subject(:pr_link) { runner.pr_link }

    context 'when the output includes a PR link for a workplace' do
      let(:create_pr_command_output) do
        'content https://github.com/software-company/the-app/pull/198 more content'
      end

      it 'returns the PR link' do
        expect(pr_link).to eq('https://github.com/software-company/the-app/pull/198')
      end
    end

    context 'when the output includes a PR link for david_runger' do
      let(:create_pr_command_output) do
        'content https://github.com/davidrunger/david_runger/pull/199 more content'
      end

      it 'returns the PR link' do
        expect(pr_link).to eq('https://github.com/davidrunger/david_runger/pull/199')
      end
    end

    context 'when the output does not include a PR link' do
      let(:create_pr_command_output) do
        'All cruelty springs from weakness.'
      end

      it 'returns nil' do
        expect(pr_link).to eq(nil)
      end
    end
  end
end
