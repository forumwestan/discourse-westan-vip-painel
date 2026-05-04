# frozen_string_literal: true

module WestanVipPainel
  class Engine < ::Rails::Engine
    engine_name WestanVipPainel::PLUGIN_NAME
    isolate_namespace WestanVipPainel
    config.autoload_paths << File.join(config.root, "lib")
  end
end
