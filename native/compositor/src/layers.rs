//! O lugar das camadas (layer-shell, Fase 14.27): a conta pura, sem Wayland.
//!
//! Uma camada (a barra, o fundo, o menu do Omarchy) não escolhe onde fica:
//! ela diz em quais bordas da saída quer encostar (as "âncoras"), a distância
//! delas (as margens), o tamanho (0 = "estica entre as duas âncoras") e se
//! reserva uma faixa da tela (a "zona exclusiva": a barra de 26 px reserva o
//! alto, e as janelas não ficam embaixo dela).
//!
//! A ordem é a do wlroots/sway: primeiro as camadas que reservam espaço (da
//! sobreposição para o fundo), cada uma dentro do que sobrou; depois as
//! outras, dentro da área útil final (ou da saída inteira, se pediram -1).

use smithay::wayland::shell::wlr_layer::{Anchor, ExclusiveZone, Layer, Margins};

use crate::pixels::Rect;

/// O que a camada pediu (o que o app mandou no último commit).
#[derive(Clone, Copy, Debug)]
pub struct LayerSpec {
    pub layer: Layer,
    /// Largura e altura pedidas (0 = esticar entre as âncoras).
    pub size: (i32, i32),
    pub anchor: Anchor,
    pub zone: ExclusiveZone,
    pub margin: Margins,
    /// Só uma camada que já aparece reserva espaço.
    pub mapped: bool,
}

/// A ordem em que as camadas são arrumadas (a de cima primeiro).
const ORDER: [Layer; 4] = [Layer::Overlay, Layer::Top, Layer::Bottom, Layer::Background];

/// Arruma as camadas de uma saída de tamanho `size`. Devolve o lugar de cada
/// uma (na mesma ordem de `specs`) e a área útil que sobra para as janelas.
pub fn arrange(size: (i32, i32), specs: &[LayerSpec]) -> (Vec<Rect>, Rect) {
    let full = Rect::new(0, 0, size.0, size.1);
    let mut usable = full;
    let mut places = vec![Rect::default(); specs.len()];
    // 1. As que reservam espaço: cada uma fica no que sobrou e come a sua faixa.
    for layer in ORDER {
        for (i, spec) in specs.iter().enumerate() {
            if spec.layer == layer && matches!(spec.zone, ExclusiveZone::Exclusive(_)) {
                places[i] = place(usable, spec);
                if spec.mapped {
                    usable = reserve(usable, spec);
                }
            }
        }
    }
    // 2. As outras: dentro da área útil (0) ou da saída inteira (-1).
    for (i, spec) in specs.iter().enumerate() {
        match spec.zone {
            ExclusiveZone::Exclusive(_) => {}
            ExclusiveZone::Neutral => places[i] = place(usable, spec),
            ExclusiveZone::DontCare => places[i] = place(full, spec),
        }
    }
    (places, usable)
}

/// O lugar da camada dentro de `bounds`: encostada nas âncoras (com as
/// margens), centralizada no eixo sem âncora (ou com as duas, se tem tamanho).
pub fn place(bounds: Rect, spec: &LayerSpec) -> Rect {
    let m = spec.margin;
    let (x, w) = axis(
        bounds.x,
        bounds.w,
        spec.size.0,
        spec.anchor.contains(Anchor::LEFT),
        spec.anchor.contains(Anchor::RIGHT),
        m.left,
        m.right,
    );
    let (y, h) = axis(
        bounds.y,
        bounds.h,
        spec.size.1,
        spec.anchor.contains(Anchor::TOP),
        spec.anchor.contains(Anchor::BOTTOM),
        m.top,
        m.bottom,
    );
    Rect::new(x, y, w, h)
}

/// Um eixo (o horizontal ou o vertical): onde começa e o tamanho.
/// `start`/`end`: âncora na borda de cima/esquerda e na de baixo/direita.
fn axis(origin: i32, length: i32, wanted: i32, start: bool, end: bool, m_start: i32, m_end: i32) -> (i32, i32) {
    let size = if wanted > 0 { wanted } else { (length - m_start - m_end).max(1) };
    let pos = match (start, end) {
        (true, false) => origin + m_start,
        (false, true) => origin + length - size - m_end,
        // As duas ou nenhuma: no meio do espaço entre as margens.
        _ => origin + m_start + (length - m_start - m_end - size) / 2,
    };
    (pos, size)
}

/// A área útil depois que a camada reserva a faixa dela. Só vale encostada
/// numa borda (ou numa borda e nas duas do lado: a barra de ponta a ponta);
/// num canto ou no meio, a zona exclusiva não reserva nada.
pub fn reserve(usable: Rect, spec: &LayerSpec) -> Rect {
    let ExclusiveZone::Exclusive(zone) = spec.zone else { return usable };
    let zone = zone as i32;
    let a = spec.anchor;
    let m = spec.margin;
    let horizontal = Anchor::LEFT | Anchor::RIGHT;
    let vertical = Anchor::TOP | Anchor::BOTTOM;
    let mut r = usable;
    if a == Anchor::TOP || a == Anchor::TOP | horizontal {
        let cut = zone + m.top;
        r.y += cut;
        r.h -= cut;
    } else if a == Anchor::BOTTOM || a == Anchor::BOTTOM | horizontal {
        r.h -= zone + m.bottom;
    } else if a == Anchor::LEFT || a == Anchor::LEFT | vertical {
        let cut = zone + m.left;
        r.x += cut;
        r.w -= cut;
    } else if a == Anchor::RIGHT || a == Anchor::RIGHT | vertical {
        r.w -= zone + m.right;
    }
    r.w = r.w.max(0);
    r.h = r.h.max(0);
    r
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec(layer: Layer, size: (i32, i32), anchor: Anchor, zone: i32) -> LayerSpec {
        LayerSpec { layer, size, anchor, zone: zone.into(), margin: Margins::default(), mapped: true }
    }

    const SAIDA: (i32, i32) = (1920, 1080);
    const BARRA: Anchor = Anchor::TOP.union(Anchor::LEFT).union(Anchor::RIGHT);

    #[test]
    fn barra_de_ponta_a_ponta_reserva_o_alto() {
        let barra = spec(Layer::Top, (0, 26), BARRA, 26);
        let (places, usable) = arrange(SAIDA, &[barra]);
        assert_eq!(places[0], Rect::new(0, 0, 1920, 26));
        assert_eq!(usable, Rect::new(0, 26, 1920, 1054));
    }

    #[test]
    fn fundo_ocupa_a_saida_inteira_mesmo_com_a_barra() {
        let fundo = spec(Layer::Background, (0, 0), Anchor::all(), -1);
        let barra = spec(Layer::Top, (0, 26), BARRA, 26);
        let (places, usable) = arrange(SAIDA, &[fundo, barra]);
        assert_eq!(places[0], Rect::new(0, 0, 1920, 1080), "-1: a saída inteira");
        assert_eq!(usable.y, 26);
    }

    #[test]
    fn camada_sem_ancora_fica_no_meio_da_area_util() {
        let barra = spec(Layer::Top, (0, 30), BARRA, 30);
        let menu = spec(Layer::Overlay, (600, 400), Anchor::empty(), 0);
        let (places, _) = arrange(SAIDA, &[barra, menu]);
        // Área útil: y de 30 a 1080 (1050 de altura): o meio vertical é 30 + 325.
        assert_eq!(places[1], Rect::new(660, 355, 600, 400));
    }

    #[test]
    fn margens_afastam_da_borda_e_entram_na_reserva() {
        let mut barra = spec(Layer::Top, (0, 30), BARRA, 30);
        barra.margin = Margins { top: 5, right: 10, bottom: 0, left: 10 };
        let (places, usable) = arrange(SAIDA, &[barra]);
        assert_eq!(places[0], Rect::new(10, 5, 1900, 30));
        assert_eq!(usable, Rect::new(0, 35, 1920, 1045));
    }

    #[test]
    fn duas_barras_empilham_e_a_de_baixo_reserva_o_pe() {
        let cima = spec(Layer::Top, (0, 26), BARRA, 26);
        let outra = spec(Layer::Top, (0, 20), BARRA, 20);
        let pe = spec(Layer::Bottom, (0, 40), Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT, 40);
        let (places, usable) = arrange(SAIDA, &[cima, outra, pe]);
        assert_eq!(places[1], Rect::new(0, 26, 1920, 20), "a segunda fica logo abaixo da primeira");
        assert_eq!(places[2], Rect::new(0, 1040, 1920, 40));
        assert_eq!(usable, Rect::new(0, 46, 1920, 994));
    }

    #[test]
    fn canto_e_lado_esquerdo() {
        let canto = spec(Layer::Overlay, (300, 100), Anchor::TOP | Anchor::RIGHT, 100);
        let (places, usable) = arrange(SAIDA, &[canto]);
        assert_eq!(places[0], Rect::new(1620, 0, 300, 100));
        assert_eq!(usable, Rect::new(0, 0, 1920, 1080), "no canto, a zona exclusiva não reserva");
        let lado = spec(Layer::Top, (48, 0), Anchor::LEFT | Anchor::TOP | Anchor::BOTTOM, 48);
        let (_, usable) = arrange(SAIDA, &[lado]);
        assert_eq!(usable, Rect::new(48, 0, 1872, 1080));
    }

    #[test]
    fn camada_escondida_nao_reserva() {
        let mut barra = spec(Layer::Top, (0, 26), BARRA, 26);
        barra.mapped = false;
        let (places, usable) = arrange(SAIDA, &[barra]);
        assert_eq!(places[0], Rect::new(0, 0, 1920, 26), "mas já tem lugar (para o primeiro configure)");
        assert_eq!(usable, Rect::new(0, 0, 1920, 1080));
    }
}
