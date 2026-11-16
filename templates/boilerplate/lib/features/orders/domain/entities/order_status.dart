/// Where an order stands.
///
/// [unknown] keeps a row readable when a newer backend sends a status this build does not know yet: the order
/// still shows, with a neutral label, instead of the whole list failing.
enum OrderStatus { pending, paid, shipped, cancelled, unknown }
