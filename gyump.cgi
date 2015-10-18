#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#

# require 'rubygems'
require 'cgi'
require 'sdbm'
require 'erb'

class Memo
  # ユーザ指定URL                          整形後URL                             hostname           id      @host      @short
  # -----------------------------------------------------------------------------------------------------------------
  # http://3memo.com/masui/             => http://masui.3memo.com/               masui              ''      ''         masui/
  # http://3memo.com/masui              => http://masui.3memo.com/               masui              ''      ''         masui
  # http://3memo.com/masui/abc          => http://masui.3memo.com/abc            masui              abc     ''         masui/abc
  # http://3memo.com/masui/abc/def      => http://abc.masui.3memo.com/def        abc.masui          def     ''         masui/abc/def
  # http://abc.masui.3memo.com/         => http://abc.masui.3memo.com/           abc.masui          ''      abc.masui  ''
  # http://masui.3memo.com/abc/         => http://abc.masui.3memo.com/           abc.masui          ''      masui      abc/
  # http://masui.3memo.com/abc          => http://masui.3memo.com/abc            masui              abc     masui      abc
  # http://masui.3memo.com/abc/def/     => http://def.abc.masui.3memo.com/       def.abc.masui      ''      masui      abc/def/
  # http://masui.3memo.com/abc/def      => http://abc.masui.3memo.com/def        abc.masui          def     masui      abc/def
  # http://abc.masui.3memo.com/def      => http://abc.masui.3memo.com/def        abc.masui          def     abc.masui  def
  # http://abc.masui.3memo.com/def/ghi/ => http://ghi.def.abc.masui.3memo.com/   ghi.def.abc.masui  ''      abc.masui  def/ghi/
  # http://abc.masui.3memo.com/def/ghi  => http://def.abc.masui.3memo.com/ghi    def.abc.masui      ghi     abc.masui  def/ghi

  def log(s)
    File.open("log/log","a"){ |f|
      f.puts s
    }
  end

  def convert(host,short)
    if host == '' && short !~ /\// then
      short += '/'
    end
    if short =~ /^(.*)\/$/ then
      a1 = $1.split(/\//).reverse
      id = ''
    else
      a1 = short.split(/\//).reverse
      id = a1.shift.to_s
    end
    a2 = host.split(/\./)
    return [(a1 + a2).join('.'),id]
  end

  def erb(template)
    ERB.new(File.read("views/#{template.to_s}.erb")).result(binding)
  end

  def initialize
    @dbm = SDBM.open('db/db',0666)
    @titledbm = SDBM.open('db/titledb',0666)
    @datedbm = SDBM.open('db/datedb',0666)
    @commentdbm = SDBM.open('db/commentdb',0666)
    @tagsdbm = SDBM.open('db/tagsdb',0666)
    @cgi = CGI.new('html3')
    @hostname = `hostname`.chomp
    #ENV['HTTP_HOST'] =~ /^(.*)memo.#{@hostname}$/
    ENV['HTTP_HOST'] =~ /^(.*)#{@hostname}$/
    @host = $1.to_s.sub(/\.$/,'')
    @short = @cgi['short'].to_s
    @long = @cgi['long'].to_s
    @title = @cgi['title'].to_s
    @tags = @cgi['tags'].to_s
    @comment = @cgi['comment'].to_s

    (@host,@short) = convert(@host,@short)
    @root = "#{@host}.#{@hostname}"

    log "#{Time.now.strftime('%Y%m%d%H%M%S')} #{@host} #{@short}"

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
    # @dbm.each { |key,value|
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
    @cgi.out { erb :list }
  end

  def edit?
    @long == '' && (@short =~ /!$/ || @dbm[@ind].to_s == '') ||
      @long != '' && @short == '' ||
      @register == '' && @long == '' && ENV['HTTP_REFERER'].to_s.index(@root) # Don't jump if accessed from the memo site.
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
    log "long = #{@long}, title = #{@title}"
    @dbm[@ind] = (@long.length > 0 ? @long : nil)
    @titledbm[@ind] = @title
    @datedbm[@ind] = Time.now.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    @commentdbm[@ind] = @comment
    @tagsdbm[@ind] = @tags

    if @tags != '' then # || @comment != '' then
      require 'atomutil'

      post_uri = 'http://b.hatena.ne.jp/atom/post'
      user = 'masui'
      pass = 'pobox652'

      tags = "[" + @tags.split(/\s+/).join("][") + "]"

      entry = Atom::Entry.new({
                                :title => 'TITLE TITLE',
                                :link => Atom::Content.new{ |c|
                                  c.set_attr(:rel, 'related')
                                  c.set_attr(:type, 'text/html')
                                  c.set_attr(:href, @long)
                                },
                                :summary => Atom::Content.new { |c|
                                  c.body = "#{tags} #{@comment}"
                                  c.set_attr(:type, "text/plain")
                                },
                              })

      auth = Atompub::Auth::Wsse.new :username => user, :password => pass
      client = Atompub::Client.new :auth => auth

      res = client.create_entry(post_uri, entry)
    end


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
end
  
memo = Memo.new

if memo.iphone? then
  memo.iphone
elsif memo.opensearch? then
  memo.opensearch
elsif memo.atom? then
  memo.atom
elsif memo.dict? then
  memo.dict
elsif memo.dumpdata? then
  memo.dumpdata
elsif !memo.valid? then
  memo.google
elsif memo.index? then
  memo.index
elsif memo.list? then
  memo.list
elsif memo.edit? then
  memo.edit
elsif memo.register? then
  memo.register
else
  memo.show
end
