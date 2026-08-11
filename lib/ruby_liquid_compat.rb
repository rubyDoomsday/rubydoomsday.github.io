# github-pages pins liquid to exactly 4.0.3, which still calls the long-deprecated
# Object#tainted?/#taint (fully removed from Ruby core in 3.2+). Restore them as the
# harmless no-ops they already were for years before removal, so local builds on modern
# Ruby don't crash on `{% assign %}`/`{% include %}` tags.
#
# This can't live in _plugins/ - the github-pages gem forces Jekyll's safe mode on by
# default (to mirror GitHub's own production build), and safe mode ignores all custom
# plugins. Required directly from the Gemfile instead, so it runs before anything else.
#
# GitHub's production build uses an older Ruby that still has these methods natively, so
# this shim only ever matters locally; it has no effect on what actually gets deployed.
unless Object.method_defined?(:tainted?)
  class Object
    def tainted?
      false
    end

    def taint
      self
    end
  end
end
