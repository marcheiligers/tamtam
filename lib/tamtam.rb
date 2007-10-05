require "rubygems"
require "hpricot"

# Takes CSS + HTML and converts it to inline styles.
# css    <=  '#foo { font-color: blue; }'
# html   <=  '<div id="foo">woot</div>'    
# output =>  '<div id="foo" style="font-color: blue;">woot</div>'
#
# The class uses regular expressions to parse the CSS.
# The regular expressions are based on CPAN's CSS::Parse::Lite.
#
# Author: Dave Hoover of Obtiva Corp.
# Sponsor: Gary Levitt of MadMimi.com
class TamTam
  UNSUPPORTED = /(::first-letter|:link|:visited|:hover|:active)$/
  
  class << self
    def inline(args)
      css, doc = process(args)
      raw_styles(css).each do |raw_style|
        style, contents = parse(raw_style)        
        next if style.match(UNSUPPORTED)
        (doc/style).each do |element|
          apply_to(element, style, contents)
        end
      end
      doc.to_s
    end

    private
    
      def process(args)
        if args[:document]
          doc = Hpricot(args[:document])
          style = (doc/"style").first
          [(style && style.inner_html), doc]
        else
          [args[:css], Hpricot(args[:body])]
        end
      end
    
      def raw_styles(css)
        return [] if css.nil?
        css = css.gsub(/[\r\n]/, " ")
        validate(css)
        # jamming brackets back on, wishing for look-behinds
        styles = css.strip.split("}").map { |style| style + "}" }
        # running backward to allow for "last one wins"
        styles.reverse
      end
      
      def validate(css)
        lefts = bracket_count(css, "{")
        rights = bracket_count(css, "}")
        if lefts != rights
          raise InvalidStyleException, "Found #{lefts} left brackets and #{rights} right brackets in:\n #{css}"
        end
      end
      
      def bracket_count(css, bracket)
        css.scan(Regexp.new(Regexp.escape(bracket))).size
      end
      
      def parse(raw_style)
        # Regex from CSS::Parse::Lite
        data = raw_style.match(/^\s*([^{]+?)\s*\{(.*)\}\s*$/)
        raise "Invalid style: #{style}" if data.nil?
        data.captures.map { |s| s.strip }
      end
      
      def apply_to(element, style, contents)
        return unless element.respond_to?(:get_attribute)
        current_style = to_hash(element.get_attribute(:style))
        new_styles = to_hash(contents).merge(current_style)
        element.set_attribute(:style, prepare(new_styles))
      rescue Exception => e
        raise Exception.new(e), "Trouble on style #{style} on element #{element}: #{e}"
      end
      
      def to_hash(style)
        return {} if style.nil?
        hash = {}
        pieces = style.strip.split(";").map { |s| s.strip.split(":").map { |kv| kv.strip } }
        pieces.each do |key, value|
          hash[key] = value
        end
        hash
      end
      
      def prepare(style_hash)
        sorted_styles = style_hash.keys.sort.map { |key| key + ": " + style_hash[key] }
        sorted_styles.join("; ").strip + ";"
      end
  end
end

class InvalidStyleException < Exception
end  
# "Man Chocolate" (don't ask)