/// A page's index, plus the edit counter when its fetch went out, so an edit can tell pages read before
/// it from pages read after. In the key because ISP carries keys into every copy of the state.
typedef PageKey = ({int index, int readStamp});
