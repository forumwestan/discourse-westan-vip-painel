# frozen_string_literal: true

require "file_helper"
require "fastimage"

module WestanVipPainel
  class BadgeImage
    class Invalid < StandardError; end

    def self.validate!(url, kind:)
      clean = Preferences.media_url(url)
      raise Invalid, "Informe uma URL HTTPS válida para a imagem." if clean.blank?
      file = FileHelper.download(clean, max_file_size: 5.megabytes,
                                 tmp_file_name: "premium-badge", follow_redirect: true)
      raise Invalid, "Não foi possível carregar a imagem (limite de 5 MB)." unless file
      type = FastImage.type(file)
      file.rewind
      size = FastImage.size(file)
      formats = kind == :logo ? %i[png webp] : %i[png jpeg gif]
      minimum = kind == :logo ? [230, 90] : [455, 120]
      raise Invalid, "Formato inválido para #{kind == :logo ? 'o logo' : 'o background'}." unless formats.include?(type)
      unless size && size[0] >= minimum[0] && size[1] >= minimum[1]
        raise Invalid, "A imagem deve ter no mínimo #{minimum.join(' × ')} pixels (largura × altura)."
      end
      clean
    rescue Invalid
      raise
    rescue StandardError
      raise Invalid, "Não foi possível validar a imagem. Confira a URL e tente novamente."
    ensure
      file&.close!
    end
  end
end
