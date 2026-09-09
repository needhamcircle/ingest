# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "needham_circle"
require "minitest/autorun"
require "socket"

require "support/sync_calendar"

module NeedhamCircle
  class Test < Minitest::Test
    private

    def with_server(response)
      dumped = JSON.dump(response)
      transport = [
        "HTTP/1.1 200 OK",
        "Content-Type: application/json",
        "Content-Length: #{dumped.bytesize}",
        "",
        dumped
      ].join("\r\n")

      server = TCPServer.new(0)
      thread =
        Thread.new do
          client = server.accept

          headers = client.gets("\r\n\r\n")
          length = headers[/^Content-Length:\s*(\d+)/i, 1]
          client.read(Integer(length)) if length

          client.print(transport)
          client.close
        end

      begin
        yield "http://localhost:#{server.addr[1]}"
      ensure
        thread.kill
        thread.join
        server.close
      end
    end
  end
end
