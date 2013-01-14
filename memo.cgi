#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#

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
    @cgi = CGI.new('html3')
    @hostname = `hostname`.chomp
    #ENV['HTTP_HOST'] =~ /^(.*)memo.#{@hostname}$/
    ENV['HTTP_HOST'] =~ /^(.*)#{@hostname}$/
    @host = $1.to_s.sub(/\.$/,'')
    @short = @cgi['short'].to_s
    @long = @cgi['long'].to_s
    @title = @cgi['title'].to_s

#     @cgi.out {
#       s = ""
#       s += "hostname = #{@hostname}"
#       ENV.each { |key,val|
#         s += "<br>ENV[#{key}] = #{val}"
#       }
#       s += "<br>short = #{@short}"
#       s += "<br>host = #{@host}"
#       s += "<br>title = #{@title}"
#      (@host,@short) = convert(@host,@short)
#       s += "<br>short = #{@short}"
#       s += "<br>host = #{@host}"
#       s
#     }
#exit

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

  def atom?
    @short == 'atom.xml'
  end

  def dumpdata?
    @short == 'dumpdata'
  end

  def dumpdata
    @cgi.out {
      data = {}
      title = {}
      @dbm.each { |key,value|
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

  def atom
    data = {}
    title = {}
    date = {}
    @dbm.each { |key,value|
      if key =~ /^#{@host}\/(.*)/ then
        data[$1] = value
        title[$1] = @titledbm[key]
        s = @datedbm[key].to_s
        s = '2008-07-08T00:08:19+00:00' if s == ''
        date[$1] = s
      end
    }
    header = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<feed xml:lang="en-US" xmlns="http://www.w3.org/2005/Atom">
  <title>#{@host}.3memo.com</title>
  <id>tag:3memo.com:Statuses</id>
  <link href="http://#{@host}.3memo.com/" type="text/html" rel="alternate"/>
  <author><name>3memo.com</name></author>
  <subtitle>3memo updates for #{@host}</subtitle>
  <updated>#{Time.now.strftime("%Y-%m-%dT%H:%M:%S+00:00")}</updated>
EOF
  footer = <<EOF
</feed>
EOF
#    entries = data.keys.sort.collect { |key|
    entries = data.keys.sort { |a,b|
      a.gsub(/\d+/){ |s| s.rjust(10,"0") } <=>
      b.gsub(/\d+/){ |s| s.rjust(10,"0") }
    }.collect { |key|

      d = data[key].gsub(/</,'&lt;')
      t = title[key].to_s
      t = d if t == ''
      s = (d =~ /^http/ ? "<a href='#{d}'>#{t}</a>" : d)
      dt = date[key]
    <<EOF
    <entry>
      <title>#{@host}.3memo.com/#{key}</title>
      <content type="html">#{t.gsub(/&/,'')}</content>
      <id>tag:3memo.com,#{dt}:http://#{@host}.3memo.com/#{key}</id>
      <published>#{dt}</published>
      <updated>#{dt}</updated>
      <link rel="alternate" href="http://#{@host}.3memo.com/#{key}" type="text/html"/>
    </entry>
EOF
    }.join
    @cgi.out("type" => 'application/atom+xml'){ header + entries + footer }
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
#    s = "[\n" + data.keys.sort.collect { |key|
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
    @dbm.each { |key,value|
      if key =~ /^#{@host}\/(.*)/ then
        @data[$1] = value
        @titles[$1] = @titledbm[key]
      end
    }
  end

  def list
    getdata
    @cgi.out { erb :list }
  end

#        @cgi.body {
#          data = {}
#          title = {}
#          @dbm.each { |key,value|
#            if key =~ /^#{@host}\/(.*)/ then
#              data[$1] = value
#              title[$1] = @titledbm[key]
#            end
#          }
#          count = 0
##          s = "<blockquote><table width=80%>\n" + data.keys.sort.collect { |key|
#          s = "<blockquote><table>\n" + data.keys.sort { |a,b|
#            a.gsub(/\d+/){ |s| s.rjust(10,"0") } <=>
#            b.gsub(/\d+/){ |s| s.rjust(10,"0") }
#          }.collect { |key|
#            count += 1
#            d = data[key].gsub(/</,'&lt;')
#            t = title[key].to_s
#            t = d if t == ''
#            s = (d =~ /^http/ ? "<a href='#{d}'>#{t}</a>" : d)
#            "<tr><td class='td1#{count%2}'><a href='http://#{@host}.3memo.com/#{key}!'>#{key}</a></td><td class='td2#{count%2}'>#{s}</td></tr>\n"
#          }.join + "</table></blockquote>\n"
#
#          xml = "- <a href='' onClick='addp(\"http://#{@host}.3memo.com/opensearch.cgi\");'>Install search plugin</a> for Firefox/IE<p>"
#          bookmarklet = "- Use this bookmarklet for quick registration. [<a href=\"javascript:(function(){w=window.open();dt=window.getSelection();if(dt=='')dt=document.title;url=document.location.href;w.location.href='http://#{@host}.3memo.com/3memo.cgi?long='+escape(url)+'&title='+encodeURIComponent(dt);})()\">Register to #{@host}.3memo</a>]<p>"
#          access = "- Use <a href=\"http://#{@host}.3memo.com/iphone.html\">this page</a> for quick access from iPhone<p>"
#          nojump = "- <input id='nojump' type='checkbox'> Inhibit jump<p>"
#          @cgi.h1{ "Bookmarks of <i>#{@host}</i>" } + s + "<hr>" + xml + bookmarklet + access + nojump + "<hr>" + form('','','') + <<EOF
#<script type="text/javascript">
#var TOP = "http://3memo.com";
#var host = "#{@host}";
#
#function createXmlHttp(){
#    if (window.ActiveXObject) {
#        return new ActiveXObject("Microsoft.XMLHTTP");
#    } else if (window.XMLHttpRequest) {
#        return new XMLHttpRequest();
#    } else {
#        return null;
#    }
#}
#


  def edit?
    @long == '' && (@short =~ /!$/ || @dbm[@ind].to_s == '') ||
      @long != '' && @short == '' ||
      @long == '' && ENV['HTTP_REFERER'].to_s.index(@root) # Don't jump if came from the memo site.
  end

  def edit
    long = (@long == '' ? @dbm[@ind].to_s : @long)
    title = @titledbm[@ind].to_s
    title = @title if title == ''
    @title = title
    @long = long
    @cgi.out {
      erb :edit
    }
  end
#      @cgi.html {
#        @cgi.head {
#          @cgi.meta('http-equiv' => 'Content-Type', 'content' => "text/html; charset=utf-8") +
#          @cgi.link('rel' => "stylesheet", 'href' => "/3memo.css", 'type' => 'text/css') +
#          @cgi.title { "Keyword registration" }
#        } +
#        @cgi.body {
#          @cgi.h2 {
#            "keyword registration for <a href='http://#{@root}/'><i>#{@host}</i></a>"
#          } +
#          form(@short2,long,title)
#        }
#      }
#    }
#  end

  def register?
    @register != ''
  end

  def register
    @dbm[@ind] = (@long.length > 0 ? @long : nil)
    @titledbm[@ind] = @title
    @datedbm[@ind] = Time.now.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    self.list
  end

  def show
    if @dbm[@ind].to_s =~ /^(http|coscriptrun)/ && # 2009/6/4 CoScripter対応
        @nojump != 'true' then
      # print @cgi.header({'status' => 'MOVED', 'Location' => @dbm[@ind].to_s, 'Time' => Time.now})
      print @cgi.header({'status' => 'REDIRECT', 'Location' => @dbm[@ind].to_s, 'Time' => Time.now})
    else
      @cgi.out {
        @cgi.html {
          @cgi.head {
            @cgi.meta('http-equiv' => 'Content-Type', 'content' => 'text/html; charset=utf-8') +
            @cgi.link('rel' => "stylesheet", 'href' => "/3memo.css", 'type' => 'text/css') +
            @cgi.link('rel' => "apple-touch-icon", 'href' => "/3memo.png") +
            @cgi.title { @titledbm[@ind].to_s }
          } +
          @cgi.body {
            # url = "http://#{@host}.3memo.com/"
            # @dbm[@ind].to_s.gsub(/</,'&lt;') +
            # "<p><a href='#{url}'>#{url}</a>"
            url = "http://#{@host}.3memo.com/#{@short}"
            "<img src='http://mozshot.nemui.org/shot?#{@dbm[@ind].to_s}'><p>" +
            @dbm[@ind].to_s.gsub(/</,'&lt;') +
            "<p><a href='#{url}!'>編集</a>"
          }
        }
      }
    end
  end
end
  
memo = Memo.new

if memo.iphone? then
  memo.iphone
#elsif memo.atom? then
#  memo.atom
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
