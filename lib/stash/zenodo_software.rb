module Stash
  module ZenodoSoftware
    Dir.glob(File.expand_path('zenodo_software/*.rb', __dir__)).sort.each(&method(:require))
  end
end
