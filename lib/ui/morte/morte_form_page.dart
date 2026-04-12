import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/farm_options.dart';
import '../../controllers/morte_controller.dart';
import '../../models/nascimento.dart';
import '../../models/morte.dart';
import '../../session/app_session.dart';
import '../../services/geolocation_service.dart';

class MorteFormPage extends StatefulWidget {
  final Nascimento nascimento;
  final bool readOnly;
  const MorteFormPage(
      {Key? key, required this.nascimento, this.readOnly = false})
      : super(key: key);

  @override
  State<MorteFormPage> createState() => _MorteFormPageState();
}

class _MorteFormPageState extends State<MorteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dataMorte;
  late TextEditingController _fazendaController;
  List<String> _photos = [];
  String? _audioPath;
  final _descricaoController = TextEditingController();
  bool _saving = false;
  Morte? _morteExistente;
  String _tipoBaixa = Morte.tipoMorte;

  String? _locationCidade;
  String? _locationBairro;
  double? _locationLatitude;
  double? _locationLongitude;
  bool _locationLoading = false;
  String? _locationError;
  final _morteController = MorteController();

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
    // Nova baixa deve iniciar com a data atual.
    _dataMorte = DateTime.now();
    _fazendaController = TextEditingController(
      text: AppSession.fazendaSelecionada ?? widget.nascimento.fazenda,
    );

    if (widget.nascimento.morto || widget.nascimento.abatido) {
      _loadMorte();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _capturarLocalizacao();
      });
    }
  }

  Future<void> _loadMorte() async {
    print('Carregando dados da morte para CRIA: ${widget.nascimento.cria}');
    if (widget.nascimento.id == null) {
      print('ERRO: nascimento.id é null, não é possível buscar morte');
      return;
    }

    final morte =
        await _morteController.getPorNascimentoId(widget.nascimento.id!);
    if (morte != null && mounted) {
      setState(() {
        _morteExistente = morte;
        _tipoBaixa = morte.tipoBaixa;
        _dataMorte = morte.dataMorte;
        _fazendaController.text = morte.fazenda;
        _descricaoController.text = morte.descricao ?? '';

        _locationCidade = morte.locationCidade;
        _locationBairro = morte.locationBairro;
        _locationLatitude = morte.locationLatitude;
        _locationLongitude = morte.locationLongitude;

        // Carregar fotos
        final fotosTemp = <String>[];
        if (morte.foto1 != null) fotosTemp.add(morte.foto1!);
        if (morte.foto2 != null) fotosTemp.add(morte.foto2!);
        if (morte.foto3 != null) fotosTemp.add(morte.foto3!);
        _photos = fotosTemp;
      });
      print('Dados da morte carregados com sucesso');
    } else {
      print('Nenhuma morte encontrada ou widget desmontado');
    }
  }

  Future<void> _capturarLocalizacao() async {
    print('Capturando localização no MorteFormPage');
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

  @override
  void dispose() {
    _fazendaController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      if (_photos.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo de 3 fotos atingido.')),
        );
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _photos.add(base64Encode(bytes));
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto capturada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao capturar foto: $e')),
      );
    }
  }

  Future<void> _openWhatsAppAudio() async {
    final url =
        'https://wa.me/?text=Audio%20da%20morte%20da%20CRIA%20${widget.nascimento.cria}';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final morte = Morte(
        id: _morteExistente?.id,
        nascimentoId: widget.nascimento.id!,
        tipoBaixa: _tipoBaixa,
        dataMorte: _dataMorte,
        fazenda:
            _morteExistente == null && AppSession.fazendaSelecionada != null
                ? AppSession.fazendaSelecionada!
                : _fazendaController.text,
        foto1: _photos.isNotEmpty ? _photos[0] : null,
        foto2: _photos.length > 1 ? _photos[1] : null,
        foto3: _photos.length > 2 ? _photos[2] : null,
        audio: _audioPath,
        descricao: _descricaoController.text,
        locationCidade: _locationCidade,
        locationBairro: _locationBairro,
        locationLatitude: _locationLatitude,
        locationLongitude: _locationLongitude,
        usuarioId: AppSession.usuarioId!,
        criadoEm: _morteExistente?.criadoEm ?? DateTime.now(),
        atualizadoEm: DateTime.now(),
      );
      await _morteController.salvar(
        morte: morte,
        animalId: widget.nascimento.id!,
        morteExistenteId: _morteExistente?.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nascimento;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nascimento.morto || widget.nascimento.abatido
            ? (widget.readOnly
                ? 'Baixa - ${n.cria}'
                : 'Editar Baixa - ${n.cria}')
            : 'Registrar Baixa - ${n.cria}'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Data nascimento
              Row(
                children: [
                  const Icon(Icons.cake, color: Colors.brown),
                  const SizedBox(width: 8),
                  Text(
                      'Nascimento: ${DateFormat('dd/MM/yyyy').format(n.dataNascimento)}'),
                ],
              ),
              const SizedBox(height: 8),
              // Data baixa
              Row(
                children: [
                  const Icon(Icons.close, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Data da baixa:'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.readOnly
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dataMorte,
                              firstDate: n.dataNascimento,
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setState(() => _dataMorte = picked);
                          },
                    child: Text(DateFormat('dd/MM/yyyy').format(_dataMorte)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipoBaixa,
                      decoration:
                          const InputDecoration(labelText: 'Tipo de baixa'),
                      items: const [
                        DropdownMenuItem(
                          value: Morte.tipoMorte,
                          child: Text('Morte'),
                        ),
                        DropdownMenuItem(
                          value: Morte.tipoAbate,
                          child: Text('Abate'),
                        ),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _tipoBaixa = v);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Fazenda
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fazendaController.text.isEmpty
                          ? null
                          : _fazendaController.text,
                      decoration: const InputDecoration(labelText: 'Fazenda'),
                      items: kFazendas
                          .map((f) => DropdownMenuItem<String>(
                                value: f,
                                child: Text(f),
                              ))
                          .toList(),
                      onChanged: !widget.readOnly
                          ? (v) =>
                              setState(() => _fazendaController.text = v ?? '')
                          : null,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Informe a fazenda' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              // Identificadores
              Row(
                children: [
                  Expanded(child: Text('ID Animal: ${n.cria}')),
                  Expanded(
                      child: Text('ID Vaca: ${n.mae.isEmpty ? "N/A" : n.mae}')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Sexo: ${n.sexo}')),
                  Expanded(child: Text('Raça: ${n.raca}')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Pelagem: ${n.pelagem}')),
                ],
              ),
              if (n.observacao != null && n.observacao!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Observação do Nascimento:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(n.observacao!),
                  ],
                ),
              const SizedBox(height: 16),
              // Fotos do nascimento
              if (n.foto1 != null || n.foto2 != null || n.foto3 != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fotos do Nascimento:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (n.foto1 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _expandirFoto(n.foto1!),
                                child: Image.memory(
                                  base64Decode(n.foto1!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (n.foto2 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _expandirFoto(n.foto2!),
                                child: Image.memory(
                                  base64Decode(n.foto2!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (n.foto3 != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _expandirFoto(n.foto3!),
                                child: Image.memory(
                                  base64Decode(n.foto3!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('DADOS DA BAIXA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: widget.readOnly ? null : _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                        ),
                        const Text('Foto'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        IconButton(
                          onPressed:
                              widget.readOnly ? null : _openWhatsAppAudio,
                          icon: const Icon(Icons.mic),
                        ),
                        const Text('Áudio'),
                      ],
                    ),
                  ),
                ],
              ),
              if (_photos.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Fotos da Morte:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          _photos.length,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                GestureDetector(
                                  onTap: () => _expandirFoto(_photos[i]),
                                  child: Image.memory(
                                    base64Decode(_photos[i]),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (!widget.readOnly)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _photos.removeAt(i)),
                                      child: Container(
                                        color: Colors.black54,
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                minLines: 2,
                maxLines: 4,
                enabled: !widget.readOnly,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a descrição'
                    : null,
              ),
              const SizedBox(height: 24),
              if (!widget.readOnly)
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Salvar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 16),
              Text('Usuário: ${AppSession.usuarioNome ?? ''}'),
            ],
          ),
        ),
      ),
    );
  }
}
