#!/usr/bin/ruby
# coding: utf-8
# -*- coding: utf-8 -*-
#
require 'cgi'
require 'sdbm'
require 'erb'

class Gyump
  #
  #                                hostname_subdomain(HTTP_HOST)で計算  CGI引数        table_id(subdomain,arg)で計算
  # ユーザ指定URL                                hostname   subdomain   arg             table              id
  # ------------------------------------------------------------------------------------------------------------------
  # (http://gyump.com/masui                      gyump.com  ''          masui           masui              '' => masui/ に redirect)
  # http://gyump.com/masui/                      gyump.com  ''          masui/          masui              ''
  # http://gyump.com/masui/abc                   gyump.com  ''          masui/abc       masui              abc
  # http://gyump.com/masui/abc/def               gyump.com  ''          masui/abc/def   abc.masui          def
  # http://abc.masui.gyump.com/                  gyump.com  abc.masui   ''              abc.masui          ''
  # http://masui.gyump.com/abc/                  gyump.com  masui       abc/            abc.masui          ''
  # http://masui.gyump.com/abc                   gyump.com  masui       abc             masui              abc
  # http://masui.gyump.com/abc/def/              gyump.com  masui       abc/def/        def.abc.masui      ''
  # http://masui.gyump.com/abc/def               gyump.com  masui       abc/def         abc.masui          def
  # http://abc.masui.gyump.com/def               gyump.com  abc.masui   def             abc.masui          def
  # http://abc.masui.gyump.com/def/ghi/          gyump.com  abc.masui   def/ghi/        ghi.def.abc.masui  ''
  # http://abc.masui.gyump.com/def/ghi           gyump.com  abc.masui   def/ghi         def.abc.masui      ghi
  # http://localhost/~masui/Gyump/masui/         localhost  ''          masui/          masui              ''
  # http://localhost/~masui/Gyump/masui/abc      localhost  ''          masui/abc       masui              abc
  # http://localhost/~masui/Gyump/masui/abc/def  localhost  ''          masui/abc/def   abc.masui          def
  # http://localhost/~masui/Gyump/masui/abc/def/ localhost  ''          masui/abc/def/  def.abc.masui      ''

  def hostname_subdomain(http_host) # "masui.gyump.com" => ["gyump.com", "masui"]
    a = ("."+http_host.to_s).split('.')
    hostname = a[-2..-1].to_a.join('.').sub(/^\./,'')
    subdomain = a[0..-3].to_a.join('.').sub(/^\./,'')
    [hostname, subdomain]
  end

  def table_id(host,arg)  # ("gyump.com", "masui/abc") => ["masui", 1, "abc"]
    log "table_id(#{host},#{arg})"
    if host == '' && arg !~ /\// then # case1
      print @cgi.header({'status' => 'REDIRECT', 'Location' => "#{ENV['REQUEST_URI']}/", 'Time' => Time.now})
      exit
    end
    log "table_id...(#{host},#{arg})"
    if arg =~ /^(.*)\/$/ then
      a = $1.split(/\//).reverse
      id = ''
    else
      a = arg.split(/\//).reverse
      id = a.shift.to_s
    end
    a += host.split(/\./)
    return [a.join('.'),a.length,id]
  end

  def initialize(cgi=nil)
    log "initialize========================"
    
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

    @arg = @cgi['arg'].to_s
    @long = @cgi['long'].to_s
    @title = @cgi['title'].to_s
    @tags = @cgi['tags'].to_s
    @comment = @cgi['comment'].to_s

    (@hostname, @subdomain) = hostname_subdomain(ENV['HTTP_HOST'])

    log "http_host = #{ENV['HTTP_HOST']}"
    log "cgitable = #{@cgi['table']}"
    log "hostname = #{@hostname}"
    log "subdomain = #{@subdomain}"
    log "arg = #{@arg}"

    @subdomain = @cgi['table'] if @cgi['table'].to_s != ''
    @arg = @cgi['id'] if @cgi['id'].to_s != ''
    
    (@table,@tablelen,@id) = table_id(@subdomain,@arg)
    
    log "after table_id: table = #{@table}"
    log "id = #{@id}"

    @root = "#{@table}.#{@hostname}"       # e.g. "masui.localhost", "masui.gyump.com"
    @base = (['..'] * @tablelen).join('/') # e.g. "..", "../.."
    log "base = #{@base}"

    log "#{Time.now.strftime('%Y%m%d%H%M%S')} root=#{@root}"

    @id2 = @id.sub(/!$/,'')
    @ind = "#{@table}/#{@id2}"
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
    (@dbm[@ind] || @register != '' || @id =~ /!$/ || @id == '') && (@id2 =~ /^[a-zA-Z0-9_\-]*$/)
  end

  def google
    log "#{Time.now.strftime('%Y%m%d%H%M%S')} #{@table} #{@arg} (Google)"

    print @cgi.header({'status' => 'MOVED', 'Location' => "http://google.com/search?q=#{@arg}"})
  end

  def index?
    @id == '' && @table == ''
  end

  def index
    @cgi.out { File.read('index.html') }
  end

  def dumpdata?
    @id == 'dumpdata'
  end

  def dumpdata
    @cgi.out {
      data = {}
      title = {}
      # @dbm.each { |key,value|
      @dbm.keys.each { |key|
        value = @dbm[key]
        if key =~ /^#{@table}\/(.*)/ then
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
    @arg == 'atom.xml'
  end

  def atom
    @data = {}
    @title = {}
    @date = {}
    # @dbm.each { |key,value|
    @dbm.keys.each { |key|
      value = @dbm[key]
      if key =~ /^#{@table}\/(.*)/ then
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
     @arg == 'dict.js'
  end

  def dict
    data = {}
    title = {}
    @dbm.each { |key,value|
      if key =~ /^#{@table}\/(.*)/ then
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
    @arg == 'iphone.html'
  end

  def iphone
    @cgi.out {
      erb :iphone
    }
  end

  def list?
    @id == '' && @long == ''
  end

  def getdata
    @data = {}
    @titles = {}
    @comments = {}
    # @dbm.each { |key,value| バグでこれが動かない?
    @dbm.keys.each { |key|
      value = @dbm[key]
      if key =~ /^#{@table}\/(.*)/ then
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
    log "@id = #{@id}"
    @long == '' && (@id =~ /!$/ || @dbm[@ind].to_s == '') ||
      # @long != '' && @id == '' ||
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
    log "register: long = #{@long}, id=#{@id}, title = #{@title}"
    @dbm[@ind] = (@long.length > 0 ? @long : nil)
    @titledbm[@ind] = @title
    @datedbm[@ind] = Time.now.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    @commentdbm[@ind] = @comment
    @tagsdbm[@ind] = @tags
    
    # @base = "."
    self.list
  end

  def opensearch?
    @arg =~ /^opensearch/
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

  def erb(template)
    ERB.new(File.read("views/#{template.to_s}.erb")).result(binding)
  end

  def log(s)
    File.open("log/log","a"){ |f|
      f.puts s
    }
  end

  def run
    log "run: id=#{@id}"
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
    
    def test_hostname_subdomain
      gyump = Gyump.new({})
      assert_equal  gyump.hostname_subdomain('localhost'), ['localhost', '']
      assert_equal  gyump.hostname_subdomain('masui.gyump.com'), ['gyump.com', 'masui']
    end

    def test_table_id
      gyump = Gyump.new({})
      assert_equal  gyump.table_id('cat.masui','abc'), ['cat.masui', 'abc']
      assert_equal  gyump.table_id('cat.masui','abc/'), ['abc.cat.masui', '']
      assert_equal  gyump.table_id('cat.masui','abc/def'), ['abc.cat.masui', 'def']
      assert_equal  gyump.table_id('cat.masui','abc/def/'), ['def.abc.cat.masui', '']
    end
  end
end
