# zywny_mockup

Protótipo navegável da interface de estudo (as telas de celular do artefato
"zywny — interface de estudo"). **Não é o app**: as partituras são imagens
prontas em `assets/` (`just mockup-images`), sem o Verovio.

Membro do pub workspace da raiz (R12): usa o tema e os widgets do app por
`package:zywny`, e nada daqui entra no APK nem no build Web do app.

    just run-mockup           # Linux, sem Impeller
    just build-mockup-apk     # APK arm64 (com.example.zywny_mockup)
    just install-mockup-apk
    just build-mockup-linux
