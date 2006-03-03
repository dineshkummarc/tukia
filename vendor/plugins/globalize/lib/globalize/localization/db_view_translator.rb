module Globalize # :nodoc:
  class DbViewTranslator 
    include Singleton

    # The maximum size of the cache in kilobytes. 
    # This is just a rough estimate, the cache can grow bigger than this figure.
    attr_accessor :max_cache_size

    attr_reader :cache_size, :cache_total_hits, :cache_total_queries

    def fetch(key, language, default = nil, arg = nil) # :nodoc:

      # use argument as pluralization number, if number
      num = arg.kind_of?(Numeric) ? arg : nil

      # if there's no translation, use default or original key      
      real_default = default || key

      result = fetch_from_cache(key, language, real_default, num)

      if num
        return result.sub('%d', num.to_s)
      else
        return arg.nil? ? result : result.sub('%s', arg.to_s)
      end
    end

    def set(key, language, translations, zero_form = nil) # :nodoc:
      raise ArgumentError, "No language set" if !language
      if translations.kind_of? Array
        translations = [ zero_form ] + translations
      else
        translations = [ zero_form, translations ]
      end

      idx = 0
      translations.each do |translation|
        set_pluralized(key, language, idx, translation)
        idx += 1
      end
    end

    # Returns the number of items in the cache.
    def cache_count
      @cache.size
    end

    # Resets the cache and its statistics -- for testing.
    def cache_reset
      cache_clear
      @cache_total_hits = 0
      @cache_total_queries = 0
    end

    private
      def fetch_view_translation(key, language, idx)
        tr = nil
        ViewTranslation.transaction do
          tr = ViewTranslation.pick(key, language, idx)

          # fill in a nil record for missed translations report
          # do not report missing zero-forms -- they're optional
          if !tr && idx != 0
            tr = ViewTranslation.create!(:tr_key => key, 
              :language_id => language.id, :pluralization_index => idx,
              :text => nil)
          end
        end

        tr ? tr.text : nil
      end

      def set_pluralized(key, language, idx, translation)
        invalidate_cache(key, language, idx)
        ViewTranslation.transaction do
          old_tr = ViewTranslation.pick(key, language, idx)
          if old_tr
            old_tr.update_attribute(:text, translation)
          else
            ViewTranslation.create!(:tr_key => key, 
              :language_id => language.id, :pluralization_index => idx, 
              :text => translation)
          end
        end 
      end

      def cache_fetch(key, language, idx)
        @cache_total_queries += 1
        cache_key = cache_key(key, language, idx)
        @cache_total_hits += 1 if @cache.has_key?(cache_key)
        @cache[cache_key]
      end

      def cache_add(key, language, idx, translation)
        cache_clear if @cache_size > max_cache_size * 1024
        size = key.size + (translation.nil? ? 0 : translation.size)
        @cache_size += size
        @cache[cache_key(key, language, idx)] = translation
      end

      def invalidate_cache(key, language, idx)
        tr = @cache.delete(cache_key(key, language, idx))
        size = key.size + (tr.nil? ? 0 : tr.size)
        @cache_size -= size
      end

      def cache_key(key, language, idx)
        [ key, language.code, idx ].join(':')
      end

      def cache_hit_ratio
        @cache_total_hits / @cache_total_queries
      end

      def cache_clear
        @cache.clear
        @cache_size = 0
      end

      def initialize
        @cache = {}
        @cache_size = 0
        @cache_total_hits = 0
        @cache_total_queries = 0

        # default cache size is 8mb        
        @max_cache_size = 8192
      end

      def fetch_from_cache(key, language, real_default, num)
        return real_default if language.nil?

        zero_form   = num == 0
        plural_idx  = language.plural_index(num)        # language-defined plural form
        zplural_idx = zero_form ? 0 : plural_idx # takes zero-form into account

        cached = cache_fetch(key, language, zplural_idx)
        if cached
          result = cached
        else
          result = fetch_view_translation(key, language, zplural_idx)

          # set to plural_form if no zero-form exists
          result ||= fetch_view_translation(key, language, plural_idx) if zero_form

          cache_add(key, language, zplural_idx, result)          
        end
        result ||= real_default
      end

  end
end
