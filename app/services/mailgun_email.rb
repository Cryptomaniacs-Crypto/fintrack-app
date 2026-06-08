# frozen_string_literal: true

require 'http'

module FinanceTracker
  module Services
    class MailgunEmail
      MAILGUN_API = 'https://api.mailgun.net/v3'

      def initialize
        @api_key = ENV.fetch('MAILGUN_API_KEY', nil)
        @domain  = ENV.fetch('MAILGUN_DOMAIN', nil)
        @from    = ENV.fetch('MAILGUN_FROM', "Fintrack <noreply@#{@domain}>")
      end

      def available?
        !@api_key.to_s.strip.empty? && !@domain.to_s.strip.empty?
      end

      def send_verification_email(to:, username:, verification_url:)
        send_message(
          to:      to,
          subject: 'Verify your Fintrack account',
          text:    <<~TEXT
            Hi #{username},

            Click the link below to verify your Fintrack account and set your password:

            #{verification_url}

            This link expires in 24 hours. If you did not request this, you can ignore this email.

            — Fintrack
          TEXT
        )
      end

      def send_bill_split_notification(to:, recipient_username:, owner_username:,
                                       bill_title:, bill_url:, amount:)
        send_message(
          to:      to,
          subject: "#{owner_username} sent you a bill split: #{bill_title}",
          text:    <<~TEXT
            Hi #{recipient_username},

            #{owner_username} has sent you a bill split on Fintrack.

            Bill:       #{bill_title}
            Your share: $#{amount}

            View and respond here:
            #{bill_url}

            — Fintrack
          TEXT
        )
      end

      private

      def send_message(to:, subject:, text:)
        return unless available?

        HTTP.basic_auth(user: 'api', pass: @api_key)
            .post(
              "#{MAILGUN_API}/#{@domain}/messages",
              form: { from: @from, to: to, subject: subject, text: text }
            )
      rescue StandardError
        nil
      end
    end
  end
end
