import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import '../assistance/domain.dart';
import '../garage/vehicle_image.dart';
import 'backend.dart';
import 'driver_data.dart';

Future<CatalogueChoice?> openServerCatalogue(
  BuildContext context,
  DriverRepository repository,
) => showModalBottomSheet<CatalogueChoice>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _CatalogueSheet(repository),
);

class _CatalogueSheet extends StatefulWidget {
  const _CatalogueSheet(this.repository);
  final DriverRepository repository;
  @override
  State<_CatalogueSheet> createState() => _CatalogueSheetState();
}

class _CatalogueSheetState extends State<_CatalogueSheet> {
  Json? make, model;
  late Future<CatalogueEntries> entries = _load();
  String get path {
    if (model != null) {
      return 'vehicle-catalogue/models/${model!['id']}/variants';
    }
    if (make != null) {
      return 'vehicle-catalogue/manufacturers/${make!['id']}/models';
    }
    return 'vehicle-catalogue/manufacturers';
  }

  Future<CatalogueEntries> _load() => widget.repository.cataloguePage(path);

  void _choose(Json item) {
    if (model != null) {
      Navigator.pop(
        context,
        CatalogueChoice(
          item['id'] as String,
          make!['name'] as String,
          model!['name'] as String,
          item['generation'] as String?,
          item['yearFrom'] as int?,
          item['yearTo'] as int?,
        ),
      );
      return;
    }
    setState(() {
      if (make == null) {
        make = item;
      } else {
        model = item;
      }
      entries = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CatalogueEntries>(
    future: entries,
    builder: (context, snapshot) => Screen(
      title: 'Vehicle catalogue',
      onBack: () {
        if (make == null) {
          Navigator.pop(context);
          return;
        }
        setState(() {
          if (model == null) {
            make = null;
          } else {
            model = null;
          }
          entries = _load();
        });
      },
      children: [
        SectionTitle(
          model != null
              ? '${make!['name']} ${model!['name']} variants'
              : make != null
              ? '${make!['name']} models'
              : 'Manufacturers',
        ),
        if (snapshot.connectionState != ConnectionState.done)
          const InformationNotice('Loading catalogue…')
        else if (snapshot.hasError) ...[
          InformationNotice(ApiFailure.of(snapshot.error!).message),
          ActionButton('Retry', () => setState(() => entries = _load())),
        ] else if (snapshot.data!.items.isEmpty)
          const InformationNotice('No entries. You can add a custom vehicle.')
        else ...[
          if (snapshot.data!.cached)
            const InformationNotice(
              'Showing previously loaded catalogue entries.',
            ),
          Panel.grouped(
            child: Column(
              children: [
                for (final item in snapshot.data!.items)
                  if (model == null)
                    SettingsRow(
                      icon: LucideIcons.car,
                      title: item['name'] as String,
                      onTap: () => _choose(item),
                    )
                  else
                    ListTile(
                      leading: (item['yearFrom'] ?? item['yearTo']) == null
                          ? null
                          : SizedBox(
                              width: 68,
                              child: VehicleImage(
                                Vehicle(
                                  item['id'] as String,
                                  make!['name'] as String,
                                  model!['name'] as String,
                                  (item['yearFrom'] ?? item['yearTo']) as int,
                                  '',
                                  generation: item['generation'] as String?,
                                ),
                                height: 35,
                              ),
                            ),
                      title: Text(
                        (item['generation'] ?? item['code']) as String,
                      ),
                      subtitle: Text(
                        [
                          item['yearFrom'],
                          item['yearTo'],
                        ].whereType<int>().toSet().join(' – '),
                      ),
                      onTap: () => _choose(item),
                    ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
