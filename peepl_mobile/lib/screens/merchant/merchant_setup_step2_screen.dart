import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/merchant_pricing_service.dart';
import '../../services/merchant_template_service.dart';
import '../../widgets/merchant/merchant_campaign_success_screen.dart';
import '../../widgets/merchant/merchant_interactions.dart';
import '../../widgets/merchant/merchant_package_pricing_card.dart';
import '../../widgets/merchant/merchant_skeleton.dart';
import '../../widgets/merchant/merchant_empty_state.dart';
import '../../widgets/merchant/merchant_glass_text_field.dart';
import '../../widgets/merchant/merchant_ai_card.dart';
import '../../widgets/merchant/merchant_calendar.dart';
import '../../widgets/merchant/merchant_campaign_stepper.dart';
import '../../widgets/merchant/merchant_offer_editor.dart';
import '../../widgets/merchant/merchant_price_summary.dart';
import '../../widgets/merchant/merchant_radius_slider.dart';
import '../../widgets/merchant/merchant_time_selector.dart';
import '../../widgets/merchant/peepl_merchant_tokens.dart';

class MerchantSetupStep2Screen extends StatefulWidget {
  const MerchantSetupStep2Screen({super.key});

  @override
  State<MerchantSetupStep2Screen> createState() =>
      _MerchantSetupStep2ScreenState();
}

class _MerchantSetupStep2ScreenState extends State<MerchantSetupStep2Screen> {
  static const _ctaPresets = ['Get Deal', 'Visit Us', 'Order Now'];

  static const _campaignTypes = [
    _CampaignType('Happy Hour', Icons.local_bar_rounded, '🍻',
        'Drive traffic during slow hours'),
    _CampaignType('Live Music', Icons.music_note_rounded, '🎵',
        'Promote tonight\'s performers'),
    _CampaignType('Trivia Night', Icons.quiz_rounded, '🧠',
        'Fill seats on weekday nights'),
    _CampaignType('Game Day', Icons.sports_football_rounded, '🏈',
        'Capitalize on sports crowds'),
    _CampaignType('Ladies Night', Icons.celebration_rounded, '💃',
        'Target weekend nightlife'),
    _CampaignType('Lunch Special', Icons.lunch_dining_rounded, '🥗',
        'Reach the nearby lunch crowd'),
    _CampaignType('Weekend Special', Icons.weekend_rounded, '✨',
        'Stand out on busy weekends'),
    _CampaignType('Holiday Event', Icons.card_giftcard_rounded, '🎁',
        'Seasonal promotions that convert'),
    _CampaignType('Custom Promotion', Icons.edit_rounded, '⭐',
        'Build your own offer from scratch'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _headlineCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _customCtaCtrl = TextEditingController();
  final _ctaUrlCtrl = TextEditingController();
  final _targetLocationCtrl = TextEditingController();

  int _step = 0;
  File? _adImageFile;
  String? _advertiserName;
  String? _campaignType;
  String _selectedCta = 'Get Deal';
  String _duration = '3';
  double _radiusMiles = 1.0;
  final Set<DateTime> _selectedSlots = {};
  bool _loadingMerchant = true;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _headlineCtrl.addListener(_refresh);
    _bodyCtrl.addListener(_refresh);
    _loadMerchantName();
  }

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _bodyCtrl.dispose();
    _customCtaCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _targetLocationCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String get _ctaText {
    final custom = _customCtaCtrl.text.trim();
    return custom.isNotEmpty ? custom : _selectedCta;
  }

  CampaignQuote get _quote {
    final sorted = _selectedSlots.toList()..sort();
    final demandBySlot = {
      for (final slot in sorted)
        slot: MerchantPricingService.demandForSlot(slot),
    };
    return MerchantPricingService.quoteHourlySlots(
      slots: sorted,
      radiusMiles: _radiusMiles,
      demandBySlot: demandBySlot,
      package: MerchantPricingService.packageForKey(_duration),
    );
  }

  String get _durationLabel => MerchantPricingService.packageKeyLabel(_duration);

  String get _scheduleLabel =>
      MerchantPricingService.formatScheduleRange(_selectedSlots);

  void _applyTemplate(MerchantCampaignTemplate template) {
    setState(() {
      _campaignType = template.campaignType;
      _headlineCtrl.text = template.headline;
      _bodyCtrl.text = template.bodyText;
      _selectedCta = template.ctaText;
      _ctaUrlCtrl.text = template.ctaUrl;
      _duration = template.duration;
      _radiusMiles = template.radiusMiles;
      _targetLocationCtrl.text = template.targetLocation;
      _step = 2;
    });
  }

  Future<void> _saveCurrentAsTemplate() async {
    final name = _campaignType ?? _headlineCtrl.text.trim();
    if (name.isEmpty) return;
    await MerchantTemplateService.saveTemplate(
      MerchantCampaignTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        campaignType: _campaignType,
        headline: _headlineCtrl.text.trim(),
        bodyText: _bodyCtrl.text.trim(),
        ctaText: _ctaText,
        ctaUrl: _ctaUrlCtrl.text.trim(),
        duration: _duration,
        radiusMiles: _radiusMiles,
        targetLocation: _targetLocationCtrl.text.trim(),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? PeeplMerchantTokens.danger : PeeplMerchantTokens.accentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadMerchantName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('merchants').doc(uid).get();
      if (doc.exists && mounted) {
        _advertiserName = doc.data()?['businessName'] as String?;
      }
    } catch (_) {
      // Preview can still render without advertiser name.
    } finally {
      if (mounted) setState(() => _loadingMerchant = false);
    }
  }

  Future<void> _pickAdImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _adImageFile = File(picked.path));
      }
    } catch (_) {
      _showSnackBar('Could not select image. Please try again.');
    }
  }

  Future<String> _uploadAdImage(String uid) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref('ad_images/$uid/$timestamp.jpg');
    await ref.putFile(_adImageFile!);
    return ref.getDownloadURL();
  }

  Future<void> _launchCampaign() async {
    if (_launching) return;
    if (_adImageFile == null) {
      _showSnackBar('Please upload a promotion image.');
      return;
    }
    if (_headlineCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      _showSnackBar('Please complete your offer copy.');
      return;
    }
    if (_ctaUrlCtrl.text.trim().isEmpty) {
      _showSnackBar('Please add a CTA URL.');
      return;
    }
    if (_selectedSlots.isEmpty) {
      _showSnackBar('Please select at least one time slot.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('You must be signed in to launch a campaign.');
      return;
    }

    setState(() => _launching = true);
    try {
      final imageUrl = await _uploadAdImage(uid);
      final sortedSlots = _selectedSlots.toList()..sort();
      final campaignStart = sortedSlots.first;
      final campaignEnd = sortedSlots.last.add(const Duration(hours: 1));
      final quote = _quote;
      final radiusLabel = '${_radiusMiles.toStringAsFixed(_radiusMiles == 1 ? 0 : 1)} mile radius';
      final targetLocation = _targetLocationCtrl.text.trim().isNotEmpty
          ? _targetLocationCtrl.text.trim()
          : radiusLabel;

      await FirebaseFirestore.instance.collection('native_ads').add({
        'advertiserId': uid,
        'advertiserName': _advertiserName ?? '',
        'imageUrl': imageUrl,
        'headline': _headlineCtrl.text.trim(),
        'bodyText': _bodyCtrl.text.trim(),
        'ctaText': _ctaText,
        'ctaUrl': _ctaUrlCtrl.text.trim(),
        'tier': 'hourly',
        'billingModel': 'hourly_slots',
        'estimatedTotal': quote.total,
        'scheduledHours': sortedSlots.length,
        'packageDuration': _duration,
        'isActive': false,
        'impressions': 0,
        'clicks': 0,
        'startDate': Timestamp.fromDate(campaignStart),
        'endDate': Timestamp.fromDate(campaignEnd),
        'priority': 1,
        'targetLocation': targetLocation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await _saveCurrentAsTemplate();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MerchantCampaignSuccessScreen(
              campaignTitle: _headlineCtrl.text.trim(),
              scheduleLabel: _scheduleLabel,
              radiusLabel:
                  '${_radiusMiles.toStringAsFixed(_radiusMiles == 1 ? 0 : 1)} miles',
              packageLabel: _durationLabel,
              onViewCampaign: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/merchant_portal',
                (_) => false,
              ),
              onCreateAnother: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MerchantSetupStep2Screen(),
                ),
              ),
              onReturnDashboard: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/merchant_portal',
                (_) => false,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      _showSnackBar('Could not launch campaign. Please try again.');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  bool get _canContinue => switch (_step) {
        0 => false,
        1 => _campaignType != null,
        2 =>
          _headlineCtrl.text.trim().isNotEmpty &&
              _bodyCtrl.text.trim().isNotEmpty &&
              _adImageFile != null,
        3 => _selectedSlots.isNotEmpty,
        4 => true,
        5 => _ctaUrlCtrl.text.trim().isNotEmpty,
        _ => false,
      };

  void _nextStep() {
    if (_step < 5) {
      setState(() => _step++);
    } else {
      _launchCampaign();
    }
  }

  void _startNewCampaign() => setState(() => _step = 1);

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
    } else if (_step == 1) {
      setState(() => _step = 0);
    } else {
      Navigator.pop(context);
    }
  }

  void _applyCampaignType(_CampaignType type) {
    setState(() {
      _campaignType = type.label;
      if (_headlineCtrl.text.trim().isEmpty) {
        _headlineCtrl.text = type.label;
      }
      if (_bodyCtrl.text.trim().isEmpty) {
        _bodyCtrl.text =
            '${type.emoji} ${type.label} at ${_advertiserName ?? 'your venue'} — tap for details!';
      }
    });
  }

  void _aiImproveCopy() {
    final current = _bodyCtrl.text.trim();
    if (current.isEmpty) return;
    setState(() {
      _bodyCtrl.text =
          '$current Limited time only — show this Peepl offer to redeem.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplMerchantTokens.background,
      body: _loadingMerchant
          ? const MerchantDashboardSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WizardHeader(onBack: _prevStep),
                if (_step > 0) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: MerchantCampaignStepper(
                      currentStep: _step,
                      totalSteps: 5,
                    ),
                  ),
                ],
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      children: [
                        if (_step == 0)
                          _StepEntry(
                            onNewCampaign: _startNewCampaign,
                            onSelectTemplate: _applyTemplate,
                          )
                        else
                          MerchantSlideTransition(
                            animationKey: ValueKey(_step),
                            child: _buildStepContent(),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_step > 0)
                  MerchantWizardNav(
                    onBack: _step > 1 ? _prevStep : () => Navigator.pop(context),
                    onContinue: _nextStep,
                    continueLabel: _step == 5 ? 'Launch Campaign' : 'Continue',
                    canContinue: _canContinue,
                    isLoading: _launching,
                    showContinue: _step != 5,
                  ),
              ],
            ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      1 => _StepCampaignType(
        key: const ValueKey(1),
        types: _campaignTypes,
        selected: _campaignType,
        onSelect: _applyCampaignType,
      ),
      2 => _StepOffer(
        key: const ValueKey(2),
        headlineCtrl: _headlineCtrl,
        bodyCtrl: _bodyCtrl,
        advertiserName: _advertiserName,
        imageFile: _adImageFile,
        ctaText: _ctaText,
        onPickImage: _pickAdImage,
        onAiImprove: _aiImproveCopy,
      ),
      3 => _StepSchedule(
        key: const ValueKey(3),
        selectedSlots: _selectedSlots,
        radiusMiles: _radiusMiles,
        onSlotsChanged: (s) => setState(() {
          _selectedSlots
            ..clear()
            ..addAll(s);
        }),
        onClear: () => setState(_selectedSlots.clear),
      ),
      4 => _StepAudience(
        key: const ValueKey(4),
        radiusMiles: _radiusMiles,
        onRadiusChanged: (v) => setState(() => _radiusMiles = v),
        targetLocationCtrl: _targetLocationCtrl,
      ),
      5 => _StepReview(
        key: const ValueKey(5),
        quote: _quote,
        promotionTitle: _headlineCtrl.text.trim(),
        campaignType: _campaignType,
        radiusMiles: _radiusMiles,
        duration: _duration,
        scheduleLabel: _scheduleLabel,
        ctaUrlCtrl: _ctaUrlCtrl,
        onDurationChanged: (d) => setState(() => _duration = d),
        onLaunch: _launchCampaign,
        launching: _launching,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _StepEntry extends StatelessWidget {
  const _StepEntry({
    required this.onNewCampaign,
    required this.onSelectTemplate,
  });

  final VoidCallback onNewCampaign;
  final ValueChanged<MerchantCampaignTemplate> onSelectTemplate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MerchantCampaignTemplate>>(
      future: MerchantTemplateService.loadSaved(),
      builder: (context, snap) {
        final saved = snap.data ?? [];
        final templates = [
          ...MerchantTemplateService.builtInTemplates,
          ...saved,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create Campaign', style: PeeplMerchantTokens.sectionTitle(context)),
            const SizedBox(height: 8),
            Text(
              'Start fresh or reuse a proven promotion template.',
              style: PeeplMerchantTokens.body(context),
            ),
            const SizedBox(height: 24),
            MerchantPrimaryButton(
              label: 'New Campaign',
              icon: Icons.add_rounded,
              onTap: onNewCampaign,
            ),
            const SizedBox(height: 28),
            Text('Use Template', style: PeeplMerchantTokens.cardTitle(context)),
            const SizedBox(height: 12),
            if (templates.isEmpty)
              const MerchantEmptyState(
                variant: MerchantEmptyStateVariant.noTemplates,
              )
            else
              ...templates.take(8).map(
                    (template) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MerchantLiftCard(
                        onTap: () => onSelectTemplate(template),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: PeeplMerchantTokens.cardDecoration(),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.bookmark_rounded,
                                  color: PeeplMerchantTokens.accentBlue,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      template.name,
                                      style: PeeplMerchantTokens.cardTitle(context),
                                    ),
                                    if (template.campaignType != null)
                                      Text(
                                        template.campaignType!,
                                        style: PeeplMerchantTokens.caption(context),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: PeeplMerchantTokens.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 16),
      decoration: PeeplMerchantTokens.heroGradient(),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded,
                color: PeeplMerchantTokens.textPrimary),
          ),
          const Expanded(
            child: Text(
              'Create Campaign',
              style: TextStyle(
                color: PeeplMerchantTokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignType {
  const _CampaignType(this.label, this.icon, this.emoji, this.description);
  final String label;
  final IconData icon;
  final String emoji;
  final String description;
}

class _StepCampaignType extends StatelessWidget {
  const _StepCampaignType({
    super.key,
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  final List<_CampaignType> types;
  final String? selected;
  final ValueChanged<_CampaignType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Campaign Type', style: PeeplMerchantTokens.sectionTitle(context)),
        const SizedBox(height: 8),
        const Text(
          'Choose a promotion template to get started.',
          style: TextStyle(color: PeeplMerchantTokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: types.length,
          itemBuilder: (context, i) {
            final type = types[i];
            final isSelected = selected == type.label;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(type),
                borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
                child: AnimatedScale(
                  scale: isSelected ? 1.02 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: isSelected
                        ? PeeplMerchantTokens.gradientCardDecoration()
                        : PeeplMerchantTokens.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 10),
                        Text(
                          type.label,
                          style: const TextStyle(
                            color: PeeplMerchantTokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.description,
                          style: const TextStyle(
                            color: PeeplMerchantTokens.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            type.icon,
                            color: isSelected
                                ? PeeplMerchantTokens.accentBlue
                                : PeeplMerchantTokens.textMuted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StepOffer extends StatelessWidget {
  const _StepOffer({
    super.key,
    required this.headlineCtrl,
    required this.bodyCtrl,
    this.advertiserName,
    this.imageFile,
    required this.ctaText,
    required this.onPickImage,
    required this.onAiImprove,
  });

  final TextEditingController headlineCtrl;
  final TextEditingController bodyCtrl;
  final String? advertiserName;
  final File? imageFile;
  final String ctaText;
  final VoidCallback onPickImage;
  final VoidCallback onAiImprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MerchantOfferEditor(
          controller: bodyCtrl,
          headlineController: headlineCtrl,
          maxLength: 100,
          advertiserName: advertiserName,
          imageFile: imageFile,
          ctaText: ctaText,
          onPickImage: onPickImage,
          onAiImprove: onAiImprove,
          suggestedCopies: const [
            '🍻 Happy Hour 4–7pm — half off appetizers!',
            '🎵 Live jazz tonight — no cover before 9pm.',
            '🏈 Game Day specials — big screens, cold drinks.',
          ],
        ),
        const SizedBox(height: 20),
        MerchantAiCard(
          onGeneratePromotion: onAiImprove,
          onImproveWording: onAiImprove,
        ),
      ],
    );
  }
}

class _StepSchedule extends StatelessWidget {
  const _StepSchedule({
    super.key,
    required this.selectedSlots,
    required this.radiusMiles,
    required this.onSlotsChanged,
    this.onClear,
  });

  final Set<DateTime> selectedSlots;
  final double radiusMiles;
  final ValueChanged<Set<DateTime>> onSlotsChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scheduling', style: PeeplMerchantTokens.sectionTitle(context)),
        const SizedBox(height: 16),
        MerchantCalendar(
          selectedSlots: selectedSlots,
          onSlotsChanged: onSlotsChanged,
          radiusMiles: radiusMiles,
        ),
        const SizedBox(height: 24),
        MerchantTimeSelector(
          selectedSlots: selectedSlots,
          radiusMiles: radiusMiles,
          onClear: onClear,
        ),
      ],
    );
  }
}

class _StepAudience extends StatelessWidget {
  const _StepAudience({
    super.key,
    required this.radiusMiles,
    required this.onRadiusChanged,
    required this.targetLocationCtrl,
  });

  final double radiusMiles;
  final ValueChanged<double> onRadiusChanged;
  final TextEditingController targetLocationCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MerchantRadiusSlider(
          radiusMiles: radiusMiles,
          onChanged: onRadiusChanged,
        ),
        const SizedBox(height: 24),
        Text(
          'Target area (optional)',
          style: PeeplMerchantTokens.sectionTitle(context),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: targetLocationCtrl,
          style: const TextStyle(color: PeeplMerchantTokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'City or neighborhood',
            hintStyle: const TextStyle(color: PeeplMerchantTokens.textMuted),
            filled: true,
            fillColor: PeeplMerchantTokens.glassFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepReview extends StatelessWidget {
  const _StepReview({
    super.key,
    required this.quote,
    required this.promotionTitle,
    this.campaignType,
    required this.radiusMiles,
    required this.duration,
    required this.scheduleLabel,
    required this.ctaUrlCtrl,
    required this.onDurationChanged,
    required this.onLaunch,
    required this.launching,
  });

  final CampaignQuote quote;
  final String promotionTitle;
  final String? campaignType;
  final double radiusMiles;
  final String duration;
  final String scheduleLabel;
  final TextEditingController ctaUrlCtrl;
  final ValueChanged<String> onDurationChanged;
  final VoidCallback onLaunch;
  final bool launching;

  @override
  Widget build(BuildContext context) {
    final durationLabel = MerchantPricingService.packageKeyLabel(duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MerchantSectionCard(
          title: 'Package & checkout',
          children: [
            MerchantPackageSelector(
              selectedDuration: duration,
              onChanged: onDurationChanged,
            ),
            const SizedBox(height: 16),
            MerchantGlassTextField(
              label: 'CTA URL',
              controller: ctaUrlCtrl,
              keyboardType: TextInputType.url,
              hint: 'https://yourbusiness.com/deal',
            ),
          ],
        ),
        const SizedBox(height: 20),
        MerchantPriceSummary(
          quote: quote,
          promotionTitle:
              promotionTitle.isNotEmpty ? promotionTitle : campaignType,
          packageLabel: durationLabel,
          dateLabel: scheduleLabel,
          radiusLabel:
              '${radiusMiles.toStringAsFixed(radiusMiles == 1 ? 0 : 1)} miles',
          paymentMethodLabel: 'Beta — no charge during beta period',
          onLaunch: onLaunch,
          isLaunching: launching,
        ),
      ],
    );
  }
}
