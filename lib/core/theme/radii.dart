/// Pixel-sharp border-radius tokens (Phase 17.0a).
///
/// The pixel-art visual direction locks every surface to hard, integer-pixel
/// edges. Rounded corners fight the 1px-grid aesthetic: they anti-alias into
/// blurred sub-pixel curves and collapse the "sprite on a tile" feel the rest
/// of the art is built around. To enforce this globally, all four semantic
/// radius tokens are pinned to `0.0`.
///
/// The names (Sm/Md/Lg/Xl) are kept because they are semantic tokens used in
/// 40+ call sites across `features/`, `shared/widgets/`, and `core/theme/`.
/// The contract is "use the token that matches the visual weight you want",
/// not "use the number that looks right". When the aesthetic changes, the
/// token values change — the call sites do not.
///
/// Two exceptions live in `AppTheme` (not here): `bottomSheetTheme` and
/// `snackBarTheme` both carry a 2px chamfer so those floating surfaces read
/// as overlays rather than fused status-bar pixels. Every other surface is
/// `BorderRadius.zero` by contract.
const kRadiusSm = 0.0;
const kRadiusMd = 0.0;
const kRadiusLg = 0.0;
const kRadiusXl = 0.0;
