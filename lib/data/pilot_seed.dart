import '../models/deck.dart';
import '../models/fact.dart';
import 'memo_repository.dart';

abstract final class PilotSeed {
  static const deckId = 'pilot.redes.transporte';

  static Future<void> ensure(MemoRepository repo) async {
    await repo.seedDeck(
      id: deckId,
      name: 'Redes · Transporte',
      description: 'Puertos, TCP/UDP y vocabulario de red.',
      domain: DeckDomain.info,
      groupName: 'Informática',
      facts: [
        for (final item in _facts)
          SeedFact(
            id: item.$1,
            prompt: item.$2,
            answer: item.$3,
            source: item.$4,
            kind: FactKind.termino,
          ),
      ],
    );
  }

  static const _facts = <(String, String, String, String)>[
    ('p01', 'Puerto HTTPS', '443', 'IANA'),
    ('p02', 'Puerto HTTP', '80', 'IANA'),
    ('p03', 'Puerto SSH', '22', 'IANA'),
    ('p04', 'Puerto DNS', '53', 'IANA'),
    ('p05', 'Puerto SMTP', '25', 'IANA'),
    ('p06', 'Puerto FTP (control)', '21', 'IANA'),
    ('p07', '¿Qué garantiza TCP que UDP no garantiza?', 'Conexión, entrega fiable y ordenada', 'Capa 4'),
    ('p08', 'PDU de la capa de transporte (TCP)', 'Segmento', 'OSI / TCP-IP'),
    ('p09', 'Handshake de establecimiento TCP', 'SYN → SYN-ACK → ACK', 'TCP'),
    ('p10', 'Rango de puertos well-known', '0–1023', 'IANA'),
    ('p11', 'Bits de una dirección IPv4', '32', 'IPv4'),
    ('p12', 'Bits de una dirección IPv6', '128', 'IPv6'),
    ('p13', 'Capa OSI de IP', 'Capa 3 (red)', 'OSI'),
    ('p14', 'Capa OSI de TCP y UDP', 'Capa 4 (transporte)', 'OSI'),
    ('p15', 'MTU típico de Ethernet', '1500 bytes', 'Ethernet'),
    ('p16', 'Puerto RDP', '3389', 'IANA'),
    ('p17', '¿Para qué sirve NAT?', 'Traducir direcciones privadas a una pública', 'Redes'),
    ('p18', '¿Qué asigna DHCP?', 'Dirección IP (y datos de red) de forma automática', 'DHCP'),
    ('p19', '¿Qué resuelve ARP?', 'Una IP a una MAC en la LAN', 'ARP'),
    ('p20', 'Protocolo de ping', 'ICMP', 'ICMP'),
    ('p21', 'Dirección de loopback IPv4', '127.0.0.1', 'IPv4'),
    ('p22', 'Máscara de un /24', '255.255.255.0', 'CIDR'),
    ('p23', '¿Qué limita el TTL de un paquete?', 'El número de saltos (se descarta al llegar a 0)', 'IP'),
    ('p24', 'Puerto 53: transporte habitual', 'UDP (TCP si la respuesta es grande)', 'DNS'),
    ('p25', 'Ventana TCP', 'Control de flujo: bytes que se pueden enviar sin ACK', 'TCP'),
    ('p26', 'Puerto MySQL', '3306', 'IANA'),
    ('p27', 'UDP en una frase', 'Sin conexión, no fiable, bajo overhead', 'Capa 4'),
    ('p28', 'Propósito del three-way handshake', 'Establecer una conexión TCP', 'TCP'),
    ('p29', 'Puerto HTTPS / TLS', '443', 'IANA'),
    ('p30', 'Hosts útiles en una red /24', '254 (256 − red − broadcast)', 'CIDR'),
  ];
}
