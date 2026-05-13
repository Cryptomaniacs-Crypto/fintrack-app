# frozen_string_literal: true

module FinanceTracker
  # HTTP request helper methods.
  class HttpRequest
    def initialize(roda_routing, secure_scheme:)
      @routing = roda_routing
      @secure_scheme = secure_scheme
    end

    def secure?
      configured = @secure_scheme.to_s.upcase
      return true unless configured == 'HTTPS'

      request_scheme.casecmp('https').zero?
    end

    def https_url
      @routing.url
              .sub(/\Ahttp:\/\//, 'https://')
              .sub(%r{\A(https://[^/:]+):80(?=/|$)}, '\1')
    end

    private

    def request_scheme
      forwarded_proto = @routing.env['HTTP_X_FORWARDED_PROTO']
      return @routing.scheme unless forwarded_proto

      forwarded_proto.split(',').first.to_s.strip
    end
  end
end
