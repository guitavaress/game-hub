//! A imagem da janela: do formato do app (shm) para o formato da Godot.
//!
//! Os apps desenham numa memória compartilhada ("shm") com os pixels em
//! BGRA (o formato `Argb8888` do Wayland, gravado ao contrário na memória).
//! A Godot quer RGBA. Aqui não tem nada de Wayland nem de Godot, só bytes:
//! por isso dá para testar com `cargo test`.
//!
//! Duas economias (Fase 14.16):
//! - só o **recorte** da janela é copiado (a sombra em volta, que apps como o
//!   Brave desenham, fica de fora);
//! - quando o app avisa o que mudou (o "dano"), só essas **linhas** são copiadas.

use std::ops::Range;

use smithay::reexports::wayland_server::protocol::wl_shm::Format;

/// Como a imagem está na memória do app.
#[derive(Clone, Copy, Debug)]
pub struct ShmLayout {
    /// Onde a imagem começa dentro da memória.
    pub offset: i32,
    pub width: i32,
    pub height: i32,
    /// Quantos bytes tem cada linha (pode sobrar espaço no fim).
    pub stride: i32,
    pub format: Format,
}

/// Um retângulo em pixels (x, y do canto de cima à esquerda).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl Rect {
    pub fn new(x: i32, y: i32, w: i32, h: i32) -> Rect {
        Rect { x, y, w, h }
    }

    /// A parte comum aos dois (largura ou altura 0 se não se tocam).
    pub fn intersect(&self, other: &Rect) -> Rect {
        let x = self.x.max(other.x);
        let y = self.y.max(other.y);
        // "saturating": os apps costumam marcar dano (0, 0, enorme, enorme) para dizer "tudo".
        let right = self.x.saturating_add(self.w).min(other.x.saturating_add(other.w));
        let bottom = self.y.saturating_add(self.h).min(other.y.saturating_add(other.h));
        Rect { x, y, w: (right - x).max(0), h: (bottom - y).max(0) }
    }

    pub fn is_empty(&self) -> bool {
        self.w <= 0 || self.h <= 0
    }
}

/// O recorte da janela dentro da imagem: a geometria que o app declarou
/// (`set_window_geometry`), sem sair da imagem. Sem geometria, a imagem toda.
pub fn crop_rect(width: i32, height: i32, geometry: Option<Rect>) -> Rect {
    let full = Rect::new(0, 0, width, height);
    match geometry {
        Some(g) if !g.is_empty() => {
            let crop = full.intersect(&g);
            if crop.is_empty() {
                full
            } else {
                crop
            }
        }
        _ => full,
    }
}

/// As linhas do recorte que o dano tocou (contadas a partir do topo do recorte).
/// Sem dano nenhum, nenhuma linha.
pub fn damaged_rows(crop: &Rect, damage: &[Rect]) -> Range<i32> {
    let mut top = i32::MAX;
    let mut bottom = i32::MIN;
    for d in damage {
        let hit = crop.intersect(d);
        if !hit.is_empty() {
            top = top.min(hit.y - crop.y);
            bottom = bottom.max(hit.y + hit.h - crop.y);
        }
    }
    if top >= bottom {
        0..0
    } else {
        top..bottom
    }
}

/// Copia as linhas `rows` do recorte `crop` da imagem do app para `dst`
/// (RGBA, do tamanho do recorte: `crop.w * crop.h * 4` bytes).
///
/// Devolve false, sem copiar nada, se o formato não for um dos dois que o hub
/// entende ou se os números não couberem (um app com defeito não derruba o hub).
pub fn copy_rows(src: &[u8], layout: &ShmLayout, crop: &Rect, rows: Range<i32>, dst: &mut [u8]) -> bool {
    // Xrgb8888: o quarto byte não vale nada, a janela é toda opaca.
    let opaque = match layout.format {
        Format::Argb8888 => false,
        Format::Xrgb8888 => true,
        _ => return false,
    };
    let inside = Rect::new(0, 0, layout.width, layout.height);
    if crop.is_empty() || inside.intersect(crop) != *crop || layout.offset < 0 || layout.width * 4 > layout.stride {
        return false;
    }
    let (o, s) = (layout.offset as usize, layout.stride as usize);
    if o + s * (layout.height as usize - 1) + layout.width as usize * 4 > src.len() {
        return false;
    }
    let (cx, cy, cw) = (crop.x as usize, crop.y as usize, crop.w as usize);
    if dst.len() != cw * crop.h as usize * 4 {
        return false;
    }
    let alpha: u32 = if opaque { 0xFF00_0000 } else { 0 };
    for y in rows.start.max(0)..rows.end.min(crop.h) {
        let y = y as usize;
        let start = o + (cy + y) * s + cx * 4;
        let row = &src[start..start + cw * 4];
        let out = &mut dst[y * cw * 4..(y + 1) * cw * 4];
        for (d, p) in out.chunks_exact_mut(4).zip(row.chunks_exact(4)) {
            // Um pixel como número: na memória B, G, R, A vira 0xAARRGGBB.
            // Trocar o 1º e o 3º byte dá R, G, B, A. Feito assim, número a
            // número, o compilador processa vários pixels de uma vez.
            let v = u32::from_le_bytes([p[0], p[1], p[2], p[3]]);
            let swapped = (v & 0xFF00_FF00) | ((v >> 16) & 0xFF) | ((v & 0xFF) << 16) | alpha;
            d.copy_from_slice(&swapped.to_le_bytes());
        }
    }
    true
}

/// Desenha a imagem `src` (RGBA, `src_w`×`src_h`) por cima de `dst`
/// (`dst_w`×`dst_h`) com o canto em (x, y). O que sair de `dst` é cortado.
/// Usado para pôr os menus por cima da janela.
///
/// As cores do Wayland vêm "pré-multiplicadas" (o vermelho de um pixel meio
/// transparente já vem pela metade), então misturar é: cor de cima +
/// cor de baixo × (1 − transparência de cima).
pub fn blend_over(dst: &mut [u8], dst_w: i32, dst_h: i32, src: &[u8], src_w: i32, src_h: i32, x: i32, y: i32) {
    blend_over_clipped(dst, dst_w, dst_h, src, src_w, src_h, x, y, Rect::new(0, 0, dst_w, dst_h));
}

/// O mesmo que `blend_over`, mas só dentro de `clip` (em pixels de `dst`).
/// Usado para pôr cada janela no lugar dela no monitor (Fase 14.26): se a
/// imagem do app ainda for maior que o lugar, o que sobra não invade a vizinha.
#[allow(clippy::too_many_arguments)]
pub fn blend_over_clipped(
    dst: &mut [u8],
    dst_w: i32,
    dst_h: i32,
    src: &[u8],
    src_w: i32,
    src_h: i32,
    x: i32,
    y: i32,
    clip: Rect,
) {
    let area = Rect::new(0, 0, dst_w, dst_h).intersect(&clip).intersect(&Rect::new(x, y, src_w, src_h));
    if area.is_empty() || dst.len() < (dst_w * dst_h * 4) as usize || src.len() < (src_w * src_h * 4) as usize {
        return;
    }
    for row in area.y..area.y + area.h {
        let d0 = ((row * dst_w + area.x) * 4) as usize;
        let s0 = (((row - y) * src_w + (area.x - x)) * 4) as usize;
        let len = (area.w * 4) as usize;
        for (d, s) in dst[d0..d0 + len].chunks_exact_mut(4).zip(src[s0..s0 + len].chunks_exact(4)) {
            if s[3] == 255 {
                d.copy_from_slice(s); // opaco (o caso mais comum): só copia
                continue;
            }
            let keep = 255 - s[3] as u32; // quanto da cor de baixo continua aparecendo
            for c in 0..4 {
                d[c] = (s[c] as u32 + (d[c] as u32 * keep + 127) / 255).min(255) as u8;
            }
        }
    }
}

/// Pinta a imagem inteira (RGBA) de uma cor só.
pub fn fill(dst: &mut [u8], color: [u8; 4]) {
    for d in dst.chunks_exact_mut(4) {
        d.copy_from_slice(&color);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn layout(width: i32, height: i32, stride: i32, format: Format) -> ShmLayout {
        ShmLayout { offset: 0, width, height, stride, format }
    }

    /// Copia a imagem inteira (o caso mais comum).
    fn copy_all(src: &[u8], l: &ShmLayout) -> Option<Vec<u8>> {
        let crop = Rect::new(0, 0, l.width, l.height);
        let mut dst = vec![0u8; (l.width * l.height * 4) as usize];
        copy_rows(src, l, &crop, 0..l.height, &mut dst).then_some(dst)
    }

    /// Um pixel BGRA como o app grava na memória.
    const BGRA: [u8; 4] = [10, 20, 30, 128];

    #[test]
    fn argb_vira_rgba() {
        assert_eq!(copy_all(&BGRA, &layout(1, 1, 4, Format::Argb8888)).unwrap(), vec![30, 20, 10, 128]);
    }

    #[test]
    fn xrgb_fica_opaco() {
        assert_eq!(copy_all(&BGRA, &layout(1, 1, 4, Format::Xrgb8888)).unwrap(), vec![30, 20, 10, 255]);
    }

    #[test]
    fn respeita_offset_e_sobra_no_fim_da_linha() {
        // 2 bytes de lixo antes, 2 linhas de 1 pixel, e 4 bytes de sobra por linha.
        let mut src = vec![0xEE, 0xEE];
        src.extend_from_slice(&[1, 2, 3, 4, 0, 0, 0, 0]);
        src.extend_from_slice(&[5, 6, 7, 8]);
        let l = ShmLayout { offset: 2, width: 1, height: 2, stride: 8, format: Format::Argb8888 };
        assert_eq!(copy_all(&src, &l).unwrap(), vec![3, 2, 1, 4, 7, 6, 5, 8]);
    }

    #[test]
    fn recusa_formato_desconhecido() {
        assert!(copy_all(&BGRA, &layout(1, 1, 4, Format::Rgb565)).is_none());
    }

    #[test]
    fn recusa_numeros_que_nao_cabem() {
        assert!(copy_all(&BGRA, &layout(2, 1, 8, Format::Argb8888)).is_none()); // falta memória
        assert!(copy_all(&BGRA, &layout(1, 1, 2, Format::Argb8888)).is_none()); // linha menor que a largura
        let negative = ShmLayout { offset: -1, ..layout(1, 1, 4, Format::Argb8888) };
        assert!(copy_all(&BGRA, &negative).is_none());
        let mut dst = vec![0u8; 4];
        let l = layout(1, 1, 4, Format::Argb8888);
        assert!(!copy_rows(&BGRA, &l, &Rect::new(0, 0, 2, 1), 0..1, &mut dst)); // recorte fora da imagem
        assert!(!copy_rows(&BGRA, &l, &Rect::new(0, 0, 1, 1), 0..1, &mut [0u8; 8])); // destino do tamanho errado
    }

    #[test]
    fn copia_so_o_recorte() {
        // Imagem 3×3: a borda é 1 (sombra), o meio é 9. O recorte é só o meio.
        let mut src = Vec::new();
        for y in 0..3 {
            for x in 0..3 {
                let v = if x == 1 && y == 1 { 9 } else { 1 };
                src.extend_from_slice(&[v, v, v, 255]);
            }
        }
        let crop = Rect::new(1, 1, 1, 1);
        let mut dst = vec![0u8; 4];
        assert!(copy_rows(&src, &layout(3, 3, 12, Format::Argb8888), &crop, 0..1, &mut dst));
        assert_eq!(dst, vec![9, 9, 9, 255]);
    }

    #[test]
    fn copia_so_as_linhas_pedidas() {
        let src = [1u8; 4 * 3]; // 1×3, tudo 1
        let mut dst = vec![0u8; 4 * 3];
        assert!(copy_rows(&src, &layout(1, 3, 4, Format::Argb8888), &Rect::new(0, 0, 1, 3), 1..2, &mut dst));
        assert_eq!(dst, vec![0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0]);
    }

    #[test]
    fn recorte_pela_geometria() {
        assert_eq!(crop_rect(1324, 764, Some(Rect::new(22, 22, 1280, 720))), Rect::new(22, 22, 1280, 720));
        assert_eq!(crop_rect(100, 50, None), Rect::new(0, 0, 100, 50));
        // Geometria maior que a imagem: fica o que cabe.
        assert_eq!(crop_rect(100, 50, Some(Rect::new(10, 0, 200, 200))), Rect::new(10, 0, 90, 50));
        // Geometria vazia ou fora da imagem: a imagem toda.
        assert_eq!(crop_rect(100, 50, Some(Rect::new(0, 0, 0, 0))), Rect::new(0, 0, 100, 50));
        assert_eq!(crop_rect(100, 50, Some(Rect::new(500, 500, 10, 10))), Rect::new(0, 0, 100, 50));
    }

    #[test]
    fn linhas_do_dano() {
        let crop = Rect::new(10, 10, 100, 100);
        assert_eq!(damaged_rows(&crop, &[]), 0..0);
        assert_eq!(damaged_rows(&crop, &[Rect::new(0, 20, 50, 5)]), 10..15);
        assert_eq!(damaged_rows(&crop, &[Rect::new(0, 20, 50, 5), Rect::new(30, 100, 5, 50)]), 10..100);
        assert_eq!(damaged_rows(&crop, &[Rect::new(0, 0, 5, 5)]), 0..0); // só na sombra
        assert_eq!(damaged_rows(&crop, &[Rect::new(0, 0, i32::MAX, i32::MAX)]), 0..100); // "tudo"
    }

    #[test]
    fn menu_por_cima_da_janela() {
        // Janela 3×2 azul; "menu" 2×1 vermelho opaco em (2, 1): só um pixel cabe.
        let mut dst = [0, 0, 255, 255].repeat(6);
        let src = [255, 0, 0, 255].repeat(2);
        blend_over(&mut dst, 3, 2, &src, 2, 1, 2, 1);
        assert_eq!(&dst[(1 * 3 + 2) * 4..(1 * 3 + 3) * 4], &[255, 0, 0, 255]);
        assert_eq!(&dst[(1 * 3 + 1) * 4..(1 * 3 + 2) * 4], &[0, 0, 255, 255], "fora do menu fica a janela");
        // Meio transparente (pré-multiplicado: vermelho 128 com alpha 128) sobre azul.
        let mut dst = [0, 0, 255, 255].to_vec();
        blend_over(&mut dst, 1, 1, &[128, 0, 0, 128], 1, 1, 0, 0);
        assert_eq!(dst, vec![128, 0, 127, 255]);
        // Totalmente fora: nada muda.
        let mut dst = [9u8; 4].to_vec();
        blend_over(&mut dst, 1, 1, &[255, 0, 0, 255], 1, 1, 5, 5);
        assert_eq!(dst, vec![9; 4]);
    }

    #[test]
    fn janela_cortada_pelo_lugar_dela() {
        // Monitor 4×1 preto; janela 3×1 branca em x = 1, mas o lugar dela só tem 2 de largura.
        let mut dst = [0, 0, 0, 255].repeat(4);
        let src = [255, 255, 255, 255].repeat(3);
        blend_over_clipped(&mut dst, 4, 1, &src, 3, 1, 1, 0, Rect::new(1, 0, 2, 1));
        assert_eq!(dst, [[0, 0, 0, 255], [255; 4], [255; 4], [0, 0, 0, 255]].concat());
    }

    #[test]
    fn pinta_de_uma_cor() {
        let mut dst = vec![0u8; 8];
        fill(&mut dst, [1, 2, 3, 4]);
        assert_eq!(dst, vec![1, 2, 3, 4, 1, 2, 3, 4]);
    }

    /// Só para comparar caminhos (rode com `cargo test --release -- --ignored --nocapture`).
    /// O número absoluto depende da máquina; a meta de desempenho é a do desktop.
    #[test]
    #[ignore]
    fn medida_1280x720() {
        let l = layout(1280, 720, 1280 * 4, Format::Xrgb8888);
        let src = vec![7u8; 1280 * 720 * 4];
        let crop = Rect::new(0, 0, 1280, 720);
        let mut dst = vec![0u8; 1280 * 720 * 4];
        let start = std::time::Instant::now();
        for _ in 0..100 {
            copy_rows(&src, &l, &crop, 0..720, &mut dst);
        }
        println!("cópia 1280×720: {:.2} ms", start.elapsed().as_secs_f64() * 1000.0 / 100.0);
    }
}
