import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sift_app/src/features/chat/presentation/controllers/settings_controller.dart';

class InternalConfigScreen extends ConsumerStatefulWidget {
  const InternalConfigScreen({super.key});

  @override
  ConsumerState<InternalConfigScreen> createState() => _InternalConfigScreenState();
}

class _InternalConfigScreenState extends ConsumerState<InternalConfigScreen> {
  int _currentStep = 0;
  bool _manualEngineSelection = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // Determine current step based on state if we want auto-advance, 
    // but a manual Stepper is usually better for UX.
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal Server Setup'),
        leading: _currentStep == 0 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          final canContinue = _canContinue(settings, _currentStep);
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: canContinue ? details.onStepContinue : null,
                    child: Text(isLastStep ? 'Finish Setup' : 'Next'),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Engine Installation'),
            subtitle: Text(settings.isEngineVerified ? 'Engine installed' : 'Download llama.cpp engine'),
            content: _buildEngineStep(settings),
            isActive: _currentStep >= 0,
            state: settings.isEngineVerified ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Hardware Audit'),
            subtitle: Text(settings.selectedDeviceId != null ? 'Device selected' : 'Choose execution device'),
            content: _buildHardwareStep(settings),
            isActive: _currentStep >= 1,
            state: settings.selectedDeviceId != null ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Model Bundle'),
            subtitle: Text(settings.isInstructInstalled ? 'Qwen3 Ready' : 'Download core model'),
            content: _buildModelStep(settings),
            isActive: _currentStep >= 2,
            state: settings.isInstructInstalled ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    final settings = ref.read(settingsProvider);
    if (_canContinue(settings, _currentStep)) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
      } else if (_currentStep == 2) {
        _finishSetup();
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _canContinue(SettingsState settings, int step) {
    switch (step) {
      case 0: return settings.isEngineVerified;
      case 1: return settings.selectedDeviceId != null;
      case 2: return settings.isInstructInstalled;
      default: return false;
    }
  }

  void _finishSetup() {
    Navigator.of(context).pop();
    ref.read(settingsProvider.notifier).completeSetup();
  }

  Widget _buildEngineStep(SettingsState settings) {
    if (settings.isFetchingEngines) {
      return const Column(
        children: [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for available engines...'),
        ],
      );
    }

    if (settings.isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Installing engine binaries...'),
          const SizedBox(height: 16),
          Text(
            '${settings.downloadProgress.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(settings.downloadStatus, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    if (settings.isEngineVerified && !_manualEngineSelection && !settings.isDownloading) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Engine Ready', style: Theme.of(context).textTheme.titleMedium),
                Text(settings.selectedEngine ?? 'Unknown Engine', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).fetchEngines();
              setState(() => _manualEngineSelection = true);
            },
            child: const Text('Change'),
          ),
        ],
      );
    }

    // Selection State
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('To run a local AI, select the llama.cpp engine binaries tailored for your OS.'),
        const SizedBox(height: 16),
        if (settings.availableEngines.isEmpty)
          Center(
            child: Column(
              children: [
                if (settings.engineFetchError != null) ...[
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    settings.engineFetchError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ] else
                  const Text('No engines found. Check your connection.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.read(settingsProvider.notifier).fetchEngines(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Fetch'),
                ),
              ],
            ),
          )
        else ...[
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Select Engine Architecture',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: settings.selectedEngine,
                isExpanded: true,
                hint: const Text('Choose an engine...'),
                items: settings.availableEngines.map((e) {
                  return DropdownMenuItem(
                    value: e.name,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setSelectedEngine(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: settings.selectedEngine == null 
                ? null 
                : () {
                    final asset = settings.availableEngines.firstWhere((e) => e.name == settings.selectedEngine);
                    ref.read(settingsProvider.notifier).downloadEngine(asset);
                    setState(() => _manualEngineSelection = false);
                  },
              icon: const Icon(Icons.download),
              label: const Text('Download and Install Engine'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We recommend Vulkan or CUDA for GPU acceleration.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildHardwareStep(SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select the hardware you want to use for AI inference. GPUs (Vulkan/CUDA) are significantly faster than CPU.'),
        const SizedBox(height: 16),
        if (settings.availableDevices.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => ref.read(settingsProvider.notifier).fetchDevices(),
              icon: const Icon(Icons.refresh),
              label: const Text('Detect Hardware'),
            ),
          )
        else
          RadioGroup<String>(
            groupValue: settings.selectedDeviceId,
            onChanged: (val) {
              if (val != null) {
                ref.read(settingsProvider.notifier).setSelectedDevice(val);
              }
            },
            child: Column(
              children: settings.availableDevices.map((device) => RadioListTile<String>(
                title: Text(device.name),
                subtitle: Text(device.isGpu ? 'Hardware Accelerator (GPU)' : 'Standard Processor (CPU)'),
                value: device.id,
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildModelStep(SettingsState settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Finally, we need to download the Qwen3 model bundle. This includes the LLM, Embedding, and Reranking models.'),
        const SizedBox(height: 16),
        if (settings.isDownloadingBundle) ...[
          Text(
            '${settings.bundleProgress.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(settings.bundleStatus, style: Theme.of(context).textTheme.bodySmall),
        ] else if (settings.isInstructInstalled) ...[
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Model bundle installed.'),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => ref.read(settingsProvider.notifier).downloadModelBundle(),
              icon: const Icon(Icons.download),
              label: const Text('Download Qwen Bundle'),
            ),
          ),
        ],
      ],
    );
  }
}
