#
# ronin-vuln - A Ruby library for blind vulnerability testing.
#
# Copyright (c) 2022 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# ronin-vuln is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ronin-vuln is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ronin-vuln.  If not, see <https://www.gnu.org/licenses/>.
#

require 'ronin/support/network/http'

module Ronin
  module Vulns
    #
    # The base class for all web vulnerabilities.
    #
    class Web

      # The URL to test or exploit.
      #
      # @return [URI::HTTP]
      attr_reader :url

      # The query param to test or exploit.
      #
      # @return [String, Symbol, nil]
      attr_reader :query_param

      # The HTTP Header name to test or exploit.
      #
      # @return [String, Symbol, nil]
      attr_reader :header_name

      # The `Cookie:` param name to test or exploit.
      #
      # @return [String, Symbol, nil]
      attr_reader :cookie_param

      # The form param name to test or exploit.
      #
      # @return [String, Symbol, nil]
      attr_reader :form_param

      # An HTTP session to use for testing the URL.
      #
      # @return [Ronin::Support::Network::HTTP, nil]
      attr_reader :http

      # The HTTP request method for each request.
      #
      # @return [:copy, :delete, :get, :head, :lock, :mkcol, :move,
      #         :options, :patch, :post, :propfind, :proppatch, :put,
      #         :trace, :unlock]
      attr_reader :request_method

      # The query params to send with each request.
      #
      # @return [Hash{String,Symbol => String}]
      attr_reader :query_params

      # The user to authenticate as.
      #
      # @return [String, nil]
      attr_reader :user

      # The password to authenticate with.
      #
      # @return [String, nil]
      attr_reader :password

      # Additional HTTP header names and values to add to the request.
      #
      # @return [Hash{Symbol,String => String}, nil]
      attr_reader :headers

      # Additional `Cookie` header. If a `Hash` is given, it will be converted
      # to a `String` using `Ronin::Support::Network::HTTP::Cookie`.
      #
      # @return [String, Hash{String => String}, nil]
      attr_reader :cookie

      # The form data that may be sent in the body of the request.
      #
      # @return [Hash, String, nil]
      attr_reader :form_data

      # The optional HTTP `Referer` header to send with each request.
      #
      # @return [String, nil]
      attr_reader :referer

      #
      # Initializes the web vulnerability.
      #
      # @param [URI::HTTP, String] url
      #   The URL to test or exploit.
      #
      # @param [String, Symbol, nil] query_param
      #   The query param to test or exploit.
      #
      # @param [String, Symbol, nil] header_name
      #   The HTTP Header name to test or exploit.
      #
      # @param [String, Symbol, nil] cookie_param
      #   The `Cookie:` param name to test or exploit.
      #
      # @param [String, Symbol, nil] form_param
      #   The form param name to test or exploit.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use for testing the URL.
      #
      # @param [:copy, :delete, :get, :head, :lock, :mkcol, :move,
      #         :options, :patch, :post, :propfind, :proppatch, :put,
      #         :trace, :unlock] request_method
      #   The HTTP request mehtod for each request.
      #
      # @param [String, nil] user
      #   The user to authenticate as.
      #
      # @param [String, nil] password
      #   The password to authenticate with.
      #
      # @param [Hash{Symbol,String => String}, nil] headers
      #   Additional HTTP header names and values to add to the request.
      #
      # @param [String, Hash{String => String}, nil] cookie
      #   Additional `Cookie` header. If a `Hash` is given, it will be
      #   converted to a `String` using `Ronin::Support::Network::HTTP::Cookie`.
      #
      # @param [Hash, String, nil] form_data
      #   The form data that may be sent in the body of the request.
      #
      # @param [String, nil] referer
      #   The optional HTTP `Referer` header to send with each request.
      #
      def initialize(url, query_param:    nil,
                          header_name:    nil,
                          cookie_param:   nil,
                          form_param:     nil,
                          # http keyword arguments
                          http:           nil,
                          request_method: :get,
                          user:           nil,
                          password:       nil,
                          headers:        nil,
                          cookie:         nil,
                          form_data:      nil,
                          referer:        nil)
        @url = URI(url)

        @query_param  = query_param
        @header_name  = header_name
        @cookie_param = cookie_param
        @form_param   = form_param

        @http = http || Support::Network::HTTP.connect_uri(@url)

        @request_method = request_method
        @query_params   = @url.query_params
        @headers        = headers
        @cookie         = cookie
        @form_data      = form_data
        @referer        = referer
      end

      #
      # Scans the query parameters of the URL.
      #
      # @param [URI::HTTP, String] url
      #   The URL to scan.
      #
      # @param [Array<Symbol, String>, Symbol, String, nil] query_params
      #   The query param name(s) to test. If no query param(s) are given,
      #   then all query params in the URL will be scanned.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use when testing for web vulnerabilities.
      #
      # @yield [vuln]
      #   If a block is given it will be yielded each discovered vulnerability.
      #
      # @yieldparam [Web] vuln
      #   A discovered vulnerability in the URL's query params.
      #
      # @return [Array<Web>]
      #   All discovered Web vulnerabilities.
      #
      def self.scan_query_params(url,query_params=nil, http: nil, **kwargs)
        url    = URI(url)
        http ||= Support::Network::HTTP.connect_uri(url)

        query_params ||= url.query_params.keys
        vulns          = []

        query_params.each do |param|
          vuln = new(url, query_param: param, http: http, **kwargs)

          if vuln.vulnerable?
            yield vuln if block_given?
            vulns << vuln
          end
        end

        return vulns
      end

      #
      # Scans the URL and request headers.
      #
      # @param [URI::HTTP, String] url
      #   The URL to scan.
      #
      # @param [Array<String, Symbol>, String, Symbol] header_names
      #   The header name(s) to test.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use when testing for web vulnerabilities.
      #
      # @yield [vuln]
      #   If a block is given it will be yielded each discovered vulnerability.
      #
      # @yieldparam [Web] vuln
      #   A discovered vulnerability in the URL and one of the header names.
      #
      # @return [Array<Web>]
      #   All discovered Web vulnerabilities.
      #
      def self.scan_headers(url,header_names, http: nil, **kwargs)
        url    = URI(url)
        http ||= Support::Network::HTTP.connect_uri(url)

        vulns = []

        header_names.each do |header_name|
          vuln = new(url, header_name: header_name, http: http, **kwargs)

          if vuln.vulnerable?
            yield vuln if block_given?
            vulns << vuln
          end
        end

        return vulns
      end

      #
      # Scans the URL and the `Cookie` header params.
      #
      # @param [URI::HTTP, String] url
      #   The URL to scan.
      #
      # @param [Array<Symbol, String>, Symbol, String, nil] cookie_params
      #   The cookie param name(s) to test. If not given, then the URL will be
      #   requested and the `Set-Cookie` params from the response will be
      #   tested instead.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use when testing for web vulnerabilities.
      #
      # @yield [vuln]
      #   If a block is given it will be yielded each discovered vulnerability.
      #
      # @yieldparam [Web] vuln
      #   A discovered vulnerability in the URL and one of the `Cookie` header
      #   params.
      #
      # @return [Array<Web>]
      #   All discovered Web vulnerabilities.
      #
      def self.scan_cookie_params(url,cookie_params=nil, http: nil, **kwargs)
        url    = URI(url)
        http ||= Support::Network::HTTP.connect_uri(url)

        unless cookie_params 
          cookie_params = Set.new

          http.get_cookies(url.request_uri).each do |set_cookie|
            cookie_params.merge(set_cookie.params.keys)
          end
        end

        vulns = []

        cookie_params.each do |cookie_param|
          vuln = new(url, cookie_param: cookie_param, http: http, **kwargs)

          if vuln.vulnerable?
            yield vuln if block_given?
            vulns << vuln
          end
        end

        return vulns
      end

      #
      # Scans the URL and the form params.
      #
      # @param [URI::HTTP, String] url
      #   The URL to scan.
      #
      # @param [Array<Symbol, String>, Symbol, String, nil] form_params
      #   The form param name(s) to test.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use when testing for web vulnerabilities.
      #
      # @yield [vuln]
      #   If a block is given it will be yielded each discovered vulnerability.
      #
      # @yieldparam [Web] vuln
      #   A discovered vulnerability in the URL and one of the form params.
      #
      # @return [Array<Web>]
      #   All discovered Web vulnerabilities.
      #
      def self.scan_form_params(url,form_params, http: nil, **kwargs)
        url    = URI(url)
        http ||= Support::Network::HTTP.connect_uri(url)

        vulns = []

        form_params.each do |form_param|
          vuln = new(url, form_param: form_param, http: http, **kwargs)

          if vuln.vulnerable?
            yield vuln if block_given?
            vulns << vuln
          end
        end

        return vulns
      end

      #
      # Scans the URL for Web vulnerabilities.
      #
      # @param [URI::HTTP, String] url
      #   The URL to scan.
      #
      # @param [Array<Symbol, String>, Symbol, String, true, nil] query_params
      #   The query param name(s) to test.
      #
      # @param [Array<Symbol, String>, Symbol, String, nil] header_names
      #   The header name(s) to test.
      #
      # @param [Array<Symbol, String>, Symbol, String, true, nil] cookie_params
      #   The cookie param name(s) to test.
      #
      # @param [Array<Symbol, String>, Symbol, String, nil] form_params
      #   The form param name(s) to test.
      #
      # @param [Ronin::Support::Network::HTTP, nil] http
      #   An HTTP session to use for testing the LFI.
      #
      # @param [Hash{Symbol => Object}] kwargs
      #   Additional keyword arguments for {#initialize}.
      #
      # @option kwargs [Hash{String => String}, nil] :headers
      #   Additional headers to send with requests.
      #
      # @option kwargs [String, Ronin::Support::Network::HTTP::Cookie, nil] :cookie
      #   Additional cookie params to send with requests.
      #
      # @option kwargs [String, nil] :referer
      #   Optional `Referer` header to send with requests.
      #
      # @option kwargs [Hash{String => String}, nil] :form_data
      #   Additional form data to send with requests.
      #
      # @yield [vuln]
      #   If a block is given it will be yielded each discovered vulnerability.
      #
      # @yieldparam [Web] vuln
      #   A discovered vulnerability in the URL.
      #
      # @return [Array<Web>]
      #   All discovered Web vulnerabilities.
      #
      def self.scan(url, query_params:  nil,
                         header_names:  nil,
                         cookie_params: nil,
                         form_params:   nil,
                         http:          nil,
                         **kwargs,
                         &block)
        url    = URI(url)
        http ||= Support::Network::HTTP.connect_uri(url)
        vulns  = []

        if (query_params.nil? && header_names.nil? && cookie_params.nil? && form_params.nil?)
          vulns.concat(scan_query_params(url, http: http, **kwargs,&block))
        else
          if query_params
            vulns.concat(
              case query_params
              when true
                scan_query_params(url, http: http, **kwargs,&block)
              else
                scan_query_params(url,query_params, http: http, **kwargs,&block)
              end
            )
          end

          if header_names
            vulns.concat(
              scan_headers(url,header_names, http: http, **kwargs,&block)
            )
          end

          if cookie_params
            vulns.concat(
              case cookie_params
              when true
                scan_cookie_params(url, http: http, **kwargs,&block)
              else
                scan_cookie_params(url,cookie_params, http: http, **kwargs,&block)
              end
            )
          end

          if form_params
            vulns.concat(
              scan_form_params(url,form_params, http: http, **kwargs,&block)
            )
          end
        end

        return vulns
      end

      #
      # Tests the URL for a Web vulnerability and returns the first found
      # vulnerability.
      #
      # @param [URI::HTTP, String] url
      #   The URL to test.
      #
      # @param [Hash{Symbol => Object}] kwargs
      #   Additional keyword arguments for {scan}.
      #
      # @option kwargs [Array<Symbol, String>, Symbol, String, nil] :query_params
      #   The query param name(s) to test.
      #
      # @option kwargs [Array<Symbol, String>, Symbol, String, nil] :header_names
      #   The header name(s) to test.
      #
      # @option kwargs [Array<Symbol, String>, Symbol, String, nil] :cookie_params
      #   The cookie param name(s) to test.
      #
      # @option kwargs [Array<Symbol, String>, Symbol, String, nil] :form_params
      #   The form param name(s) to test.
      #
      # @option kwargs [Ronin::Support::Network::HTTP, nil] :http
      #   An HTTP session to use for testing the LFI.
      #
      # @option kwargs [Hash{String => String}, nil] :headers
      #   Additional headers to send with requests.
      #
      # @option kwargs [String, Ronin::Support::Network::HTTP::Cookie, nil] :cookie
      #   Additional cookie params to send with requests.
      #
      # @option kwargs [String, nil] :referer
      #   Optional `Referer` header to send with requests.
      #
      # @option kwargs [Hash{String => String}, nil] :form_data
      #   Additional form data to send with requests.
      #
      # @return [Web, nil]
      #   The first discovered Web vulnerability or `nil` if no vulnerabilities
      #   were discovered.
      #
      def self.test(url,**kwargs)
        scan(url,**kwargs) do |vuln|
          return vuln
        end
      end

      #
      # The exploit query params with the payload injected.
      #
      # @param [#to_s] payload
      #   The payload to use for the exploit.
      #
      # @return [Hash{String,Symbol => String}]
      #   The {#query_params} with the payload injected. If {#query_param} is
      #   not set, then the unmodified {#query_params} will be returned.
      #
      def exploit_query_params(payload)
        if @query_param
          if @query_params
            @query_params.merge(@query_param.to_s => payload)
          else
            {@query_param.to_s => payload}
          end
        else
          @query_params
        end
      end

      #
      # The exploit headers with the payload injected.
      #
      # @param [#to_s] payload
      #   The payload to use for the exploit.
      #
      # @return [Hash{String,Symbol => String}]
      #   The {#headers} with the payload injected. If {#header_name} is not
      #   set, then the unmodified {#headers} will be returned.
      #
      def exploit_headers(payload)
        if @header_name
          if @headers
            @headers.merge(@header_name.to_s => payload)
          else
            {@header_name.to_s => payload}
          end
        else
          @headers
        end
      end

      #
      # The exploit cookie params with the payload injected.
      #
      # @param [#to_s] payload
      #   The payload to use for the exploit.
      #
      # @return [Hash{String,Symbol => String},
      #          Ronin::Support::Network::HTTP::Cookie]
      #   The {#cookie} with the payload injected. If {#cookie_param} is not
      #   set, then the unmodified {#cookie} will be returned.
      #
      def exploit_cookie(payload)
        if @cookie_param
          if @cookie
            @cookie.merge(@cookie_param.to_s => payload)
          else
            {@cookie_param.to_s => payload}
          end
        else
          @cookie
        end
      end

      #
      # The exploit form data with the payload injected.
      #
      # @param [#to_s] payload
      #   The payload to use for the exploit.
      #
      # @return [Hash{String,Symbol => String}, Ronin::Support::Network::HTTP::Cookie]
      #   The {#form_data} with the payload injected. If {#form_param} is not
      #   set, then the unmodified {#form_data} will be returned.
      #
      def exploit_form_data(payload)
        if @form_param
          if @form_data
            @form_data.merge(@form_param.to_s => payload)
          else
            {@form_param.to_s => payload}
          end
        else
          @form_data
        end
      end

      #
      # Exploits the web vulnerability by sending an HTTP request.
      #
      # @param [String] payload
      #   The payload for the web vulnerability.
      #
      # @param [Hash{Symbol => Object}] kwargs
      #   Additional keyword arguments for
      #   `Ronin::Support::Network::HTTP#request`.
      #
      # @return [Net::HTTPResponse]
      #
      def exploit(payload,**kwargs)
        query_params = exploit_query_params(payload)
        headers      = exploit_headers(payload)
        cookie       = exploit_cookie(payload)
        form_data    = exploit_form_data(payload)

        @http.request(
          @request_method, @url.path, user:         @user,
                                      password:     @password,
                                      query_params: query_params,
                                      cookie:       cookie,
                                      referer:      @referer,
                                      headers:      headers,
                                      form_data:    form_data,
                                      **kwargs
        )
      end

      #
      # The original value of the vulnerable query param, header, cookie param,
      # or form param.
      #
      # @return [String, nil]
      #
      def original_value
        if @query_param
          @url.query_params[@query_param]
        elsif @header_name
          @headers[@header_name]
        elsif @cookie_param
          @cookie[@cookie_param]
        elsif @form_param
          @form_data[@form_param]
        end
      end

      #
      # Determines if the {#url} is vulnerable.
      #
      # @return [Boolean]
      #   Indicates whether the URL is vulnerable.
      #
      # @abstract
      #
      def vulnerable?
        raise(NotImplementedError,"#{self.inspect} did not implement ##{__method__}")
      end

      #
      # Converts the web vulnerability into a String.
      #
      # @return [String]
      #   The String form of {#url}.
      #
      def to_s
        @url.to_s
      end

    end
  end
end
