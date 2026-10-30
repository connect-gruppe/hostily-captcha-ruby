$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "socket"
require "json"
require "hostily/captcha"

# Tiny HTTP server as stand-in for the service: answers every request with the given status and body.
class StubServer
  attr_reader :calls, :last, :port

  def initialize(status = 200, body = '{"success":true,"punkte":0,"gruende":[],"hostname":"example.de"}', delay: 0)
    @calls = 0
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new do
      loop do
        s = @server.accept
        Thread.new(s) do |c|
          request_line = c.gets
          headers = {}
          while (l = c.gets) && l != "\r\n"
            k, v = l.split(":", 2)
            headers[k.downcase] = v.strip
          end
          raw = c.read(headers["content-length"].to_i).to_s
          @calls += 1
          @last = { line: request_line, headers: headers, body: (JSON.parse(raw) rescue nil) }
          sleep delay
          c.write "HTTP/1.1 #{status} X\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
          c.close
        rescue StandardError
          nil
        end
      end
    end
  end

  def url = "http://127.0.0.1:#{@port}/"
  def close = (@thread.kill; @server.close)
end
