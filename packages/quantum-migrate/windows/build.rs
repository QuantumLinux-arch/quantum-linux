// Incrusta en cada .exe de Windows su ícono, manifiesto y datos del archivo.
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        embed_resource::compile_for("assets/app.rc", ["pasar-a-quantum"], embed_resource::NONE).manifest_optional().unwrap();
        embed_resource::compile_for("assets/instalar.rc", ["instalar-quantum"], embed_resource::NONE).manifest_optional().unwrap();
    }
}
