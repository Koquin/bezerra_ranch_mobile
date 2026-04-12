import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/nascimento_controller.dart';
import '../../config/farm_options.dart';
import '../../session/app_session.dart';
import '../../models/nascimento.dart';
import '../../services/animal_service.dart';
import '../../services/geolocation_service.dart';

class NascimentoFormPage extends StatefulWidget {
  final Nascimento? nascimento;
  final bool readOnly;
  const NascimentoFormPage({super.key, this.nascimento, this.readOnly = false});

  @override
  State<NascimentoFormPage> createState() => _NascimentoFormPageState();
}

class _NascimentoFormPageState extends State<NascimentoFormPage> {
  static const List<String> _racaOptions = [
    'NELORE',
    'CRUZADO',
    'CANCHIM',
    'ABERDEEN ANGUS',
    'GIR',
    'GIR LEITEIRO',
    'CHAROLÊS',
    'SENEPOL',
    'SINDI',
    'GUZERÁ',
    'CARACU',
  ];

  static const List<String> _pelagemOptions = [
    'BRANCA',
    'CINZA',
    'PRETA',
    'VERMELHO',
    'MALHADA',
    'RAJADA',
    'CEREJA',
    'CHITA  DE VERMELHO',
    'MANCHADA',
    'MARROM',
    'AMARELA',
    'VERMELHA CHITADA',
    'BEGE',
  ];

  final _controller = NascimentoController();
  final _animalService = AnimalService();
  final _formKey = GlobalKey<FormState>();

  final _cria = TextEditingController();
  final _mae = TextEditingController();
  final _idCria = TextEditingController();
  final _sexo = TextEditingController();
  final _raca = TextEditingController();
  final _peso = TextEditingController();
  final _pelagem = TextEditingController();
  final _fazenda = TextEditingController();
  final _obs = TextEditingController();
  String? _fotoPath;
  final List<String> _photos = []; // base64 strings, up to 3
  bool _travarDataNascimento = false;
  final _dataController = TextEditingController();

  DateTime _dataNasc = DateTime.now();
  bool _saving = false;

  String? _locationCidade;
  String? _locationBairro;
  double? _locationLatitude;
  double? _locationLongitude;
  bool _locationLoading = false;
  String? _locationError;

  final _fmt = DateFormat('dd/MM/yyyy');

  String? _normalizeRacaSelection(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    final upper = v.toUpperCase();
    if (_racaOptions.contains(upper)) return upper;

    const aliases = {
      'GUZERA': 'GUZERÁ',
      'GUZERA ': 'GUZERÁ',
      'GUZERÁ': 'GUZERÁ',
      'GUZERÁ': 'GUZERÁ',
      'CHAROLES': 'CHAROLÊS',
      'CHAROLES ': 'CHAROLÊS',
      'CHAROLÊS': 'CHAROLÊS',
    };
    return aliases[upper];
  }

  String? _normalizePelagemSelection(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    final upper = v.toUpperCase();
    if (_pelagemOptions.contains(upper)) return upper;

    const aliases = {
      'PRETA': 'RPETA',
      'VERMELHA': 'VERMELHO',
      'CHITA DE VERMELHO': 'CHITA  DE VERMELHO',
    };
    return aliases[upper];
  }

  bool get _fazendaFixaPorSessao =>
      widget.nascimento == null && (AppSession.fazendaSelecionada != null);

  void _expandirFoto(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('Entrou no initState do NascimentoFormPage');
    if (widget.nascimento != null) {
      final n = widget.nascimento!;
      // Preencher campos básicos
      _cria.text = n.cria;
      _idCria.text = n.cria;
      _mae.text = n.mae;
      _sexo.text = n.sexo;
      _raca.text = _normalizeRacaSelection(n.raca) ?? n.raca;
      _peso.text = n.peso?.toString() ?? '';
      _pelagem.text = _normalizePelagemSelection(n.pelagem) ?? n.pelagem;
      _fazenda.text = n.fazenda;
      _dataNasc = n.dataNascimento;
      _dataController.text = _fmt.format(n.dataNascimento);
      _obs.text = n.observacao ?? '';

      _locationCidade = n.locationCidade;
      _locationBairro = n.locationBairro;
      _locationLatitude = n.locationLatitude;
      _locationLongitude = n.locationLongitude;
    } else {
      _sexo.text = 'M';
      _travarDataNascimento = AppSession.travaDataNascimento;
      if (AppSession.fazendaSelecionada != null) {
        _fazenda.text = AppSession.fazendaSelecionada!;
      } else if (AppSession.lockedFazenda != null) {
        _fazenda.text = AppSession.lockedFazenda!;
      }
      if (AppSession.lockedDataNascimento != null) {
        _dataNasc = AppSession.lockedDataNascimento!;
      }
      _dataController.text = _fmt.format(_dataNasc);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _gerarCriaAoAbrir();
        _capturarLocalizacao();
      });
    }
  }

  @override
  void dispose() {
    print('Entrou no dispose do NascimentoFormPage');
    _cria.dispose();
    _idCria.dispose();
    _mae.dispose();
    _sexo.dispose();
    _raca.dispose();
    _peso.dispose();
    _pelagem.dispose();
    _fazenda.dispose();
    _obs.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _gerarCriaAoAbrir() async {
    print('Entrou no _gerarCriaAoAbrir do NascimentoFormPage');
    try {
      final proxima = await _controller.gerarProximaCriaPorUsuario(
        usuarioId: AppSession.usuarioId!,
        prefixo: AppSession.criaPrefixo!,
        inicio: AppSession.criaInicio!,
        maximo: AppSession.criaMax!,
      );

      if (!mounted) return;
      setState(() {
        _cria.text = proxima;
        _idCria.text = proxima;
      });
    } catch (e) {
      if (!mounted) return;
      final isLimite = e.toString().contains('LIMITE_ATINGIDO');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLimite
                ? 'Limite atingido. Procure o Admin.'
                : 'Falha ao gerar CRIA: $e',
          ),
        ),
      );

      if (isLimite) {
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _capturarLocalizacao() async {
    print('Capturando localização no NascimentoFormPage');
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('📍 Capturando localização...'),
            backgroundColor: Colors.blueGrey,
          ),
        );
    }
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      final info = await GeolocationService.captureLocationWithInfo();
      if (!mounted) return;
      setState(() {
        _locationCidade = info?.cidade;
        _locationBairro = info?.bairro;
        _locationLatitude = info?.latitude;
        _locationLongitude = info?.longitude;
        _locationLoading = false;
        _locationError =
            info == null ? 'Não foi possível obter localização' : null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(info == null
                  ? '❌ Não foi possível obter localização'
                  : '✅ Localização atualizada'),
              backgroundColor: info == null ? Colors.red : Colors.green,
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationError = 'Erro ao capturar localização';
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('❌ Erro ao capturar localização: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  String _formatCoord(double? value) {
    if (value == null) return '-';
    return value.toStringAsPrecision(15);
  }

  Future<void> _pickData() async {
    print('Entrou no _pickData do NascimentoFormPage');
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNasc,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dataNasc = picked;
        _dataController.text = _fmt.format(_dataNasc);
      });
      if (_travarDataNascimento) {
        AppSession.lockedDataNascimento = _dataNasc;
      }
    }
  }

  Future<void> _takePhoto() async {
    print('Entrou no _takePhoto do NascimentoFormPage');
    try {
      if (_photos.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo de 3 fotos atingido.')),
        );
        return;
      }
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _photos.add(b64);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto capturada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao capturar foto: $e')),
      );
    }
  }

  Future<void> _sendAudioToAdmin() async {
    print('Entrou no _sendAudioToAdmin do NascimentoFormPage');
    final admin = '559999536677';
    final msg = StringBuffer();
    msg.writeln('Solicitação (áudio) - dados do lançamento:');
    msg.writeln('CRIA: ${_cria.text}');
    msg.writeln('ID CRIA: ${_idCria.text}');
    msg.writeln('ID VACA (mãe): ${_mae.text}');
    msg.writeln('Sexo: ${_sexo.text}');
    msg.writeln('Raça: ${_raca.text}');
    msg.writeln('Pelagem: ${_pelagem.text}');
    msg.writeln('Fazenda: ${_fazenda.text}');
    msg.writeln('Data Nascimento: ${_fmt.format(_dataNasc)}');
    if (_fotoPath != null) msg.writeln('Foto: anexada');

    final uri = Uri.parse(
        'https://wa.me/$admin?text=${Uri.encodeComponent(msg.toString())}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    print('Entrou no _save do NascimentoFormPage, cria=${_cria.text}');
    final fazendaSessao = AppSession.fazendaSelecionada?.trim();
    if (fazendaSessao == null || fazendaSessao.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selecione uma fazenda na sessão antes de salvar o nascimento.'),
        ),
      );
      return;
    }

    if (_idCria.text.trim().isEmpty || _cria.text.trim().isEmpty) {
      await _gerarCriaAoAbrir();
      if (!mounted) return;
      if (_idCria.text.trim().isEmpty && _cria.text.trim().isEmpty) return;
    }

    final maeValida = await _validarMaeDaSessao(limparSeInvalida: true);
    if (!maeValida) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final criaVal =
          _cria.text.trim().isEmpty ? _idCria.text.trim() : _cria.text.trim();
      final pesoVal = double.tryParse(_peso.text.trim().replaceAll(',', '.'));

      final n = Nascimento(
        id: widget.nascimento?.id,
        cria: criaVal,
        mae: _mae.text.trim(),
        sexo: _sexo.text.trim().toUpperCase(),
        raca: _raca.text.trim(),
        peso: pesoVal,
        pelagem: _pelagem.text.trim(),
        dataNascimento: _dataNasc,
        fazenda: _fazendaFixaPorSessao
            ? AppSession.fazendaSelecionada!.trim()
            : _fazenda.text.trim(),
        observacao: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
        foto1: _photos.isNotEmpty ? _photos[0] : null,
        foto2: _photos.length > 1 ? _photos[1] : null,
        foto3: _photos.length > 2 ? _photos[2] : null,
        locationCidade: _locationCidade,
        locationBairro: _locationBairro,
        locationLatitude: _locationLatitude,
        locationLongitude: _locationLongitude,
        usuarioId: AppSession.usuarioId!,
        criadoEm: widget.nascimento?.criadoEm ?? DateTime.now(),
        atualizadoEm: DateTime.now(),
        morto: widget.nascimento?.morto ?? false,
      );

      if (widget.nascimento != null) {
        await _controller.update(n);
      } else {
        await _controller.insert(n);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final isUnique = e.toString().toLowerCase().contains('unique');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isUnique
                ? 'CRIA já existe. Tente novamente.'
                : 'Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _validarMaeDaSessao({required bool limparSeInvalida}) async {
    final maeId = _mae.text.trim();
    final fazendaSessao = AppSession.fazendaSelecionada?.trim();

    print(
        '[NascimentoFormPage._validarMaeDaSessao] maeId=$maeId fazendaSessao=$fazendaSessao');

    if (fazendaSessao == null || fazendaSessao.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selecione uma fazenda na sessão para validar e registrar o nascimento.'),
        ),
      );
      return false;
    }

    if (maeId.isEmpty) {
      return true;
    }

    final animalMae = await _animalService.getByCria(maeId);
    final sexoMae = animalMae?.sexo.trim().toUpperCase();
    final fazendaMae = animalMae?.fazenda.trim().toUpperCase();
    final fazendaAtual = fazendaSessao.toUpperCase();

    final valida =
        animalMae != null && sexoMae == 'F' && fazendaMae == fazendaAtual;
    if (valida) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('ID da vaca inválido: informe uma fêmea da fazenda atual.'),
      ),
    );

    if (limparSeInvalida) {
      setState(() {
        _mae.clear();
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    print('Entrou no build do NascimentoFormPage');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nascimento == null
            ? 'Novo Nascimento'
            : (widget.readOnly ? 'Nascimento' : 'Editar Nascimento')),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Row 1: Data + image
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dataController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Data de nascimento',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed:
                                  (widget.readOnly || _travarDataNascimento)
                                      ? null
                                      : _pickData,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Travar data'),
                            Checkbox(
                              value: _travarDataNascimento,
                              onChanged: widget.readOnly
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _travarDataNascimento = v ?? false;
                                        AppSession.travaDataNascimento =
                                            _travarDataNascimento;
                                        if (_travarDataNascimento) {
                                          AppSession.lockedDataNascimento =
                                              _dataNasc;
                                        } else {
                                          AppSession.lockedDataNascimento =
                                              null;
                                        }
                                      });
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Image.asset('assets/calf_born.webp',
                          width: 120, height: 120, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Fazenda
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fazenda.text.isEmpty ? null : _fazenda.text,
                      decoration: InputDecoration(
                        labelText: 'Fazenda',
                        suffixIcon: const Icon(Icons.business),
                      ),
                      items: kFazendas
                          .map((f) => DropdownMenuItem<String>(
                                value: f,
                                child: Text(f),
                              ))
                          .toList(),
                      onChanged: !widget.readOnly && !_fazendaFixaPorSessao
                          ? (v) => setState(() => _fazenda.text = v ?? '')
                          : null,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a fazenda'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: ID VACA (mãe) | ID CRIA
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mae,
                      decoration: const InputDecoration(
                          labelText: 'ID VACA (mãe)',
                          hintText: 'Identificação da vaca mãe'),
                      enabled: !widget.readOnly,
                      onFieldSubmitted: widget.readOnly
                          ? null
                          : (_) => _validarMaeDaSessao(limparSeInvalida: true),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a mãe'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _cria,
                      decoration: const InputDecoration(
                        labelText: 'ID CRIA',
                        hintText: 'Gerado automaticamente',
                      ),
                      enabled: false,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 4: Sexo | Raça
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: (_sexo.text.isEmpty ? 'M' : _sexo.text),
                      decoration:
                          const InputDecoration(labelText: 'Sexo (M/F)'),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('M')),
                        DropdownMenuItem(value: 'F', child: Text('F')),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _sexo.text = v ?? ''),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe o sexo';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _normalizeRacaSelection(_raca.text),
                      decoration: const InputDecoration(labelText: 'Raça'),
                      items: _racaOptions
                          .map((r) => DropdownMenuItem<String>(
                                value: r,
                                child: Text(r),
                              ))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _raca.text = v ?? ''),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a raça'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 5: Pelagem | Peso | Foto | Áudio(WhatsApp)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _normalizePelagemSelection(_pelagem.text),
                      decoration: const InputDecoration(labelText: 'Pelagem'),
                      items: _pelagemOptions
                          .map((p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p),
                              ))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _pelagem.text = v ?? ''),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a pelagem'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _peso,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Peso'),
                      enabled: !widget.readOnly,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: widget.readOnly ? null : _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                        ),
                        const Text('foto'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: widget.readOnly ? null : _sendAudioToAdmin,
                          icon: const Icon(Icons.mic),
                        ),
                        const Text('audio'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 6: descrição
              TextFormField(
                controller: _obs,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descrição'),
                enabled: !widget.readOnly,
              ),
              const SizedBox(height: 12),

              // Localização
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Geolocalização',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (!widget.readOnly)
                            IconButton(
                              tooltip: 'Atualizar localização',
                              onPressed: _capturarLocalizacao,
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                      if (_locationLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_locationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _locationError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Cidade: ${_locationCidade ?? '-'}'),
                      Text('Bairro: ${_locationBairro ?? '-'}'),
                      Text(
                        'Coordenadas: ${_formatCoord(_locationLatitude)}, ${_formatCoord(_locationLongitude)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Row 7: salvar
              if (!widget.readOnly)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      elevation: 6,
                      shadowColor: Colors.black45,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Salvar',
                              style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Fotos (parte inferior da tela)
              if (_photos.isNotEmpty || (widget.nascimento?.foto1 != null))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fotos',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Fotos do nascimento existente (read-only)
                          if (widget.readOnly &&
                              widget.nascimento?.foto1 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () =>
                                    _expandirFoto(widget.nascimento!.foto1!),
                                child: Image.memory(
                                  base64Decode(widget.nascimento!.foto1!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (widget.readOnly &&
                              widget.nascimento?.foto2 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () =>
                                    _expandirFoto(widget.nascimento!.foto2!),
                                child: Image.memory(
                                  base64Decode(widget.nascimento!.foto2!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (widget.readOnly &&
                              widget.nascimento?.foto3 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () =>
                                    _expandirFoto(widget.nascimento!.foto3!),
                                child: Image.memory(
                                  base64Decode(widget.nascimento!.foto3!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          // Fotos capturadas em modo de edição
                          if (!widget.readOnly)
                            ..._photos.asMap().entries.map((entry) {
                              final i = entry.key;
                              final photo = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _expandirFoto(photo),
                                      child: Image.memory(
                                        base64Decode(photo),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _photos.removeAt(i)),
                                        child: Container(
                                          color: Colors.black54,
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              // Row 8: info
              Text('Usuário: ${AppSession.usuarioNome ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
