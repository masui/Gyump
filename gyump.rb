#!/usr/bin/ruby
# coding: utf-8
# -*- coding: utf-8 -*-
#
require 'cgi'
require 'sdbm'
require 'erb'

class Gyump
  # ユーザ指定URL                          整形後URL                             hostname           id      @host      @short
  # -----------------------------------------------------------------------------------------------------------------
  # http://gyump.com/masui/             => http://masui.gyump.com/               masui              ''      ''         masui/
  # http://gyump.com/masui              => http://masui.gyump.com/               masui              ''      ''         masui
  # http://gyump.com/masui/abc          => http://masui.gyump.com/abc            masui              abc     ''         masui/abc
  # http://gyump.com/masui/abc/def      => http://abc.masui.gyump.com/def        abc.masui          def     ''         masui/abc/def
  # http://abc.masui.gyump.com/         => http://abc.masui.gyump.com/           abc.masui          ''      abc.masui  ''
  # http://masui.gyump.com/abc/         => http://abc.masui.gyump.com/           abc.masui          ''      masui      abc/
  # http://masui.gyump.com/abc          => http://masui.gyump.com/abc            masui              abc     masui      abc
  # http://masui.gyump.com/abc/def/     => http://def.abc.masui.gyump.com/       def.abc.masui      ''      masui      abc/def/
  # http://masui.gyump.com/abc/def      => http://abc.masui.gyump.com/def        abc.masui          def     masui      abc/def
  # http://abc.masui.gyump.com/def      => http://abc.masui.gyump.com/def        abc.masui          def     abc.masui  def
  # http://abc.masui.gyump.com/def/ghi/ => http://ghi.def.abc.masui.gyump.com/   ghi.def.abc.masui  ''      abc.masui  def/ghi/
  # http://abc.masui.gyump.com/def/ghi  => http://def.abc.masui.gyump.com/ghi    def.abc.masui      ghi     abc.masui  def/ghi

  # URLから取得される @host, @short から name, id を計算する
  #
  # ユーザ指定URL                          整形後URL                             name               id      @host      @short
  # -----------------------------------------------------------------------------------------------------------------
  # http://gyump.com/masui/             => http://masui.gyump.com/               masui              ''      ''         masui/
  # http://gyump.com/masui              => http://masui.gyump.com/               masui              ''      ''         masui           # case1
  # http://gyump.com/masui/abc          => http://masui.gyump.com/abc            masui              abc     ''         masui/abc
  # http://gyump.com/masui/abc/def      => http://abc.masui.gyump.com/def        abc.masui          def     ''         masui/abc/def
  # http://abc.masui.gyump.com/         => http://abc.masui.gyump.com/           abc.masui          ''      abc.masui  ''
  # http://masui.gyump.com/abc/         => http://abc.masui.gyump.com/           abc.masui          ''      masui      abc/
  # http://masui.gyump.com/abc          => http://masui.gyump.com/abc            masui              abc     masui      abc
  # http://masui.gyump.com/abc/def/     => http://def.abc.masui.gyump.com/       def.abc.masui      ''      masui      abc/def/
  # http://masui.gyump.com/abc/def      => http://abc.masui.gyump.com/def        abc.masui          def     masui      abc/def
  # http://abc.masui.gyump.com/def      => http://abc.masui.gyump.com/def        abc.masui          def     abc.masui  def
  # http://abc.masui.gyump.com/def/ghi/ => http://ghi.def.abc.masui.gyump.com/   ghi.def.abc.masui  ''      abc.masui  def/ghi/
  # http://abc.masui.gyump.com/def/ghi  => http://def.abc.masui.gyump.com/ghi    def.abc.masui      ghi     abc.masui  def/ghi

  # サブドメイン表記ができない場合
  # http://localhost/~masui/Gyump/masui/                                         masui              ''      ''         masui/
  # http://localhost/~masui/Gyump/masui/abc                                      masui              abc     ''         masui/abc
  # http://localhost/~masui/Gyump/masui/abc/def                                  abc.masui          def     ''         masui/abc/def
  # http://localhost/~masui/Gyump/masui/abc/def/                                 def.abc.masui      ''      ''         masui/abc/def/

  def log(s)
    File.open("log/log","a"){ |f|
      f.puts s
    }
  end

  def convert(host,short)
    log "convert(#{host},#{short})"
    if host == '' && short !~ /\// then # case1
      short += '/'
    end
    log "convert...(#{host},#{short})"
    if short =~ /^(.*)\/$/ then
      a1 = $1.split(/\//).reverse
      id = ''
    else
      a1 = short.split(/\//).reverse
      id = a1.shift.to_s
    end
    a2 = host.split(/\./)
    log "convert_ret(#{(a1 + a2).join('.')},#{id})"
    return [(a1 + a2).join('.'),id]
  end

  def erb(template)
    ERB.new(File.read("views/#{template.to_s}.erb")).result(binding)
  end

  def initialize(cgi=nil)
    log "initialize"
    
    @dbm = SDBM.open('db/db',0666)
    @titledbm = SDBM.open('db/titledb',0666)
    @datedbm = SDBM.open('db/datedb',0666)
    @commentdbm = SDBM.open('db/commentdb',0666)
    @tagsdbm = SDBM.open('db/tagsdb',0666)

    File.open("/tmp/log","w"){ |f|
      ENV.each { |key,val|
        f.puts "ENV[#{key}] = #{val}"
      }
    }
    
    @cgi = cgi || CGI.new('html3') # テスト / 運用
    
    @hostname = `hostname`.chomp
    log "@hostname = #{@hostname}"
    #ENV['HTTP_HOST'] =~ /^(.*)memo.#{@hostname}$/
    ENV['HTTP_HOST'] =~ /^(.*)#{@hostname}$/
    @host = @cgi['host'].to_s
    @host = $1.to_s.sub(/\.$/,'') if @host == ''
    log "http_host = #{ENV['HTTP_HOST']} @host=#{@host}"
    
    @short = @cgi['short'].to_s
    @long = @cgi['long'].to_s
    @title = @cgi['title'].to_s
    @tags = @cgi['tags'].to_s
    @comment = @cgi['comment'].to_s

    log "Before convert: hostname=#{@hostname}, host=#{@host}, long=#{@long}, short=#{@short}, title=#{@title}, tags=#{@tags}, comment=#{@comment}"
    (@host,@short) = convert(@host,@short)
    @root = "#{@host}.#{@hostname}"
    @base = (['..'] * @host.split(/\./).length).join('/')
    log "base = #{@base}"

    log "#{Time.now.strftime('%Y%m%d%H%M%S')} root=#{@root}"
    log "After convert: hostname=#{@hostname}, host=#{@host}, long=#{@long}, short=#{@short}, title=#{@title}, tags=#{@tags}, comment=#{@comment}"

    # After convert: hostname=masui.org, host=memo, long=, short=s, title=, tags=, comment=

    # http://memo.masui.org/s の場合
    # Before convert: hostname=masui.org, host=memo, long=, short=s, title=, tags=, comment=
    # After convert: hostname=masui.org, host=memo, long=, short=s, title=, tags=, comment=
                                                                  
    # http://localhost/~masui/Gyump/xxx/
    # Before convert: hostname=ToshiyukinoMBP, host=, long=, short=xxx/3, title=, tags=, comment=
    # After convert: hostname=ToshiyukinoMBP, host=xxx, long=, short=3, title=, tags=, comment=

    @short2 = @short.sub(/!$/,'')
    @ind = "#{@host}/#{@short2}"
    @register = @cgi['register'].to_s

    log "register=#{@register}, ind=#{@ind}, title=#{@title}"
  end

  def form(id='',value='',title='')
    @id = id
    @value = value
    @title = title
    erb :form
  end

  def valid?
    # @short2.length == 3 || @short == ''
    #(@short2.length == 3 || @dbm[@ind] || @register != '' || @short =~ /!$/ || @short == '') && (@short2 =~ /^[a-zA-Z0-9_\-]*$/)
    #(@short2.length == 3 || @short == '') && (@short2 =~ /^[a-zA-Z0-9_]*$/)
    (@dbm[@ind] || @register != '' || @short =~ /!$/ || @short == '') && (@short2 =~ /^[a-zA-Z0-9_\-]*$/)
  end

  def google
    log "#{Time.now.strftime('%Y%m%d%H%M%S')} #{@host} #{@short} (Google)"

    print @cgi.header({'status' => 'MOVED', 'Location' => "http://google.com/search?q=#{@short}"})
  end

  def index?
    @short == '' && @host == ''
  end

  def index
    @cgi.out { File.read('index.html') }
  end

  def dumpdata?
    @short == 'dumpdata'
  end

  def dumpdata
    @cgi.out {
      data = {}
      title = {}
      # @dbm.each { |key,value|
      @dbm.keys.each { |key|
        value = @dbm[key]
        if key =~ /^#{@host}\/(.*)/ then
          data[$1] = value
          title[$1] = @titledbm[key]
        end
      }
      s = data.keys.sort { |a,b|
        a.gsub(/\d+/){ |s| s.rjust(10,"0") } <=>
        b.gsub(/\d+/){ |s| s.rjust(10,"0") }
      }.collect { |key|
        "#{key}\t#{data[key]}\t#{title[key]}"
      }.join("\n")
    }
  end

  def atom?
    @short == 'atom.xml'
  end

  def atom
    @data = {}
    @title = {}
    @date = {}
    # @dbm.each { |key,value|
    @dbm.keys.each { |key|
      value = @dbm[key]
      if key =~ /^#{@host}\/(.*)/ then
        @data[$1] = value
        @title[$1] = @titledbm[key]
        s = @datedbm[key].to_s
        s = '2008-07-08T00:08:19+00:00' if s == ''
        @date[$1] = s
      end
    }
    @entries = @data.keys.sort { |a,b|
      a.gsub(/\d+/){ |s| s.rjust(10,"0") } <=>
      b.gsub(/\d+/){ |s| s.rjust(10,"0") }
    }
    @cgi.out("type" => 'application/atom+xml'){ erb :atom }
  end

  def dict?
     @short == 'dict.js'
  end

  def dict
    data = {}
    title = {}
    @dbm.each { |key,value|
      if key =~ /^#{@host}\/(.*)/ then
        k = $1
        #if value =~ /\.(jpg|png|gif)$/ then
          data[k] = value
          title[k] = @titledbm[key]
        #end
      end
    }
    s = "[\n" + data.keys.sort { |a,b|
      a.gsub(/\d+/){ |s| s.rjust(10,"0") } <=>
      b.gsub(/\d+/){ |s| s.rjust(10,"0") }
    }.collect { |key|
      "  [\"#{key}\", \"#{data[key]}\"]"
    }.join(",\n") + "]\n"
 
    @cgi.out { s }
  end

  def iphone?
    @short == 'iphone.html'
  end

  def iphone
    @cgi.out {
      erb :iphone
    }
  end

  def list?
    @short == '' && @long == ''
  end

  def getdata
    @data = {}
    @titles = {}
    @comments = {}
    # @dbm.each { |key,value| バグでこれが動かない?
    @dbm.keys.each { |key|
      value = @dbm[key]
      if key =~ /^#{@host}\/(.*)/ then
        @data[$1] = value
        @titles[$1] = @titledbm[key]
        @comments[$1] = @commentdbm[key].to_s
      end
    }
  end

  def list
    getdata
    log "list: base=#{@base}"
    @cgi.out { erb :list }
  end

  def edit?
    log "@long = #{@long}"
    log "@short = #{@short}"
    @long == '' && (@short =~ /!$/ || @dbm[@ind].to_s == '') ||
      # @long != '' && @short == '' ||
      # @register == '' && @long == '' && ENV['HTTP_REFERER'].to_s.index(@root) # Don't jump if accessed from the memo site.
      @register == '' && @long == '' && ENV['HTTP_REFERER'].to_s.index(ENV['HTTP_HOST']) # Don't jump if accessed from the memo site.
  end

  def edit
    long = (@long == '' ? @dbm[@ind].to_s : @long)
    title = @titledbm[@ind].to_s
    title = @title if title == ''
    @title = title
    @long = long
    @comment = @commentdbm[@ind].to_s
    @tags = @tagsdbm[@ind].to_s
    @cgi.out {
      erb :edit
    }
  end

  def register?
    @register != ''
  end

  def register
    log "register: long = #{@long}, short=#{@short}, title = #{@title}"
    @dbm[@ind] = (@long.length > 0 ? @long : nil)
    @titledbm[@ind] = @title
    @datedbm[@ind] = Time.now.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    @commentdbm[@ind] = @comment
    @tagsdbm[@ind] = @tags
    
    # @base = "."
    self.list
  end

  def opensearch?
    @short == 'opensearch'
  end

  def opensearch
    @cgi.out { erb :opensearch }
  end

  def show
    if @dbm[@ind].to_s =~ /^(http|javascript|coscriptrun)/ && # 2009/6/4 CoScripter対応
        @nojump != 'true' then
      # print @cgi.header({'status' => 'MOVED', 'Location' => @dbm[@ind].to_s, 'Time' => Time.now})
      print @cgi.header({'status' => 'REDIRECT', 'Location' => @dbm[@ind].to_s, 'Time' => Time.now})
    else
      edit
    end
  end

  def run
    log "run: short=#{@short}"
    if iphone? then
      iphone
    elsif opensearch? then
      opensearch
    elsif atom? then
      atom
    elsif dict? then
      dict
    elsif dumpdata? then
      dumpdata
    elsif !valid? then
      google
    elsif index? then
      index
    elsif list? then
      list
    elsif edit? then
      log "edit = #{edit?}"
      edit
    elsif register? then
      register
    else
      show
    end
  end
end

if __FILE__ == $0 then
  require 'minitest/autorun'

  class TestGyump < MiniTest::Test
    def setup
    end

    def test_convert
      gyump = Gyump.new({})
      assert_equal  gyump.convert('cat.masui','abc'), ['cat.masui', 'abc']
      assert_equal  gyump.convert('cat.masui','abc/def'), ['abc.cat.masui', 'def']
    end
  end
end
