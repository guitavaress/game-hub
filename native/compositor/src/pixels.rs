//! A imagem da janela: do formato do app (shm) para o formato da Godot.
//!
//! Os apps desenham numa memória compartilhada ("shm") com os pixels em
//! BGRA (o formato `Argb8888` do Wayland, gravado ao contrário na memória).
//! A Godot quer RGBA. Aqui não tem nada de Wayland nem de Godot, só bytes:
//! por isso dá para testar com `cargo test`.

use smithay::reexports::wayland_server::protocol::wl_shm::Format;

/// Copia a imagem do app para RGBA (4 bytes por pixel, linha atrás de linha).
///
/// - `src`: a memória inteira do buffer;
/// - `offset`: onde a imagem começa dentro dela;
/// - `stride`: quantos bytes tem cada linha (pode sobrar espaço no fim).
///
/// Devolve `None` se o formato não for um dos dois que o hub entende, ou se
/// os números não couberem na memória (um app com defeito não derruba o hub).
pub fn shm_to_rgba(src: &[u8], offset: i32, width: i32, height: i32, stride: i32, format: Format) -> Option<Vec<u8>> {
    // Xrgb8888: o quarto byte não vale nada, a janela é toda opaca.
    let opaque = match format {
        Format::Argb8888 => false,
        Format::Xrgb8888 => true,
        _ => return None,
    };
    if width <= 0 || height <= 0 || offset < 0 || stride < 0 {
        return None;
    }
    let (w, h, s, o) = (width as usize, height as usize, stride as usize, offset as usize);
    if w * 4 > s || o + s * (h - 1) + w * 4 > src.len() {
        return None;
    }
    let mut out = vec![0u8; w * h * 4];
    for y in 0..h {
        let row = &src[o + y * s..o + y * s + w * 4];
        let dst = &mut out[y * w * 4..(y + 1) * w * 4];
        for (d, p) in dst.chunks_exact_mut(4).zip(row.chunks_exact(4)) {
            d[0] = p[2]; // vermelho
            d[1] = p[1]; // verde
            d[2] = p[0]; // azul
            d[3] = if opaque { 255 } else { p[3] };
        }
    }
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Um pixel BGRA como o app grava na memória.
    const BGRA: [u8; 4] = [10, 20, 30, 128];

    #[test]
    fn argb_vira_rgba() {
        let out = shm_to_rgba(&BGRA, 0, 1, 1, 4, Format::Argb8888).unwrap();
        assert_eq!(out, vec![30, 20, 10, 128]);
    }

    #[test]
    fn xrgb_fica_opaco() {
        let out = shm_to_rgba(&BGRA, 0, 1, 1, 4, Format::Xrgb8888).unwrap();
        assert_eq!(out, vec![30, 20, 10, 255]);
    }

    #[test]
    fn respeita_offset_e_sobra_no_fim_da_linha() {
        // 2 bytes de lixo antes, 2 linhas de 1 pixel, e 4 bytes de sobra por linha.
        let mut src = vec![0xEE, 0xEE];
        src.extend_from_slice(&[1, 2, 3, 4, 0, 0, 0, 0]);
        src.extend_from_slice(&[5, 6, 7, 8]);
        let out = shm_to_rgba(&src, 2, 1, 2, 8, Format::Argb8888).unwrap();
        assert_eq!(out, vec![3, 2, 1, 4, 7, 6, 5, 8]);
    }

    #[test]
    fn recusa_formato_desconhecido() {
        assert!(shm_to_rgba(&BGRA, 0, 1, 1, 4, Format::Rgb565).is_none());
    }

    #[test]
    fn recusa_numeros_que_nao_cabem() {
        assert!(shm_to_rgba(&BGRA, 0, 2, 1, 8, Format::Argb8888).is_none()); // falta memória
        assert!(shm_to_rgba(&BGRA, 0, 1, 1, 2, Format::Argb8888).is_none()); // linha menor que a largura
        assert!(shm_to_rgba(&BGRA, -1, 1, 1, 4, Format::Argb8888).is_none());
        assert!(shm_to_rgba(&BGRA, 0, 0, 1, 4, Format::Argb8888).is_none());
    }
}
