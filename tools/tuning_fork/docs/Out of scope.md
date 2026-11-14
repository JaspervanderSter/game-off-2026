# Out of scope

What [[Home|Tuning Fork]] deliberately does not do, to stay much simpler
than Wwise or FMOD ([[Principles]]). Each item has a simple answer instead.

| Not here | Instead |
| --- | --- |
| Layers (several sounds played together as one event) | Mix the layers into the file in the audio editor |
| Sequences (intro, loop, outro) | Separate events the game plays in turn |
| Game parameters (RTPC, curves, `pitch_step`) | One event per case ([[Settings]]) |
| Positional 2D/3D sound, panning, attenuation | Not planned |
| Music (tracks, fades, transitions, tempo) | A separate system in the game, outside Tuning Fork |
| Ambience generators (random one-shots over beds) | Not planned |
| Effects (reverb, filters, echo) | Bake them into the file |
| Ducking, side-chain, snapshots | Group volumes the game sets ([[Groups]]) |
| Tracking which events the game uses | The team talks ([[Workflow]]) |
| Runtimes for other engines | The open [[File format]] lets others write one ([[Runtime]]) |
| Tutorials and guided tours | Tooltips and minimal visualizations ([[Tool]]) |
