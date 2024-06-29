from time import sleep
from modules.localization.proto.localization_pb2 import LocalizationEstimate
from cyber.python.cyber_py3 import cyber
from cyber.python.cyber_py3 import cyber_time

cyber.init()
node = cyber.Node("test_case")

localization_writer = node.create_writer(
    '/apollo/localization/pose', LocalizationEstimate)

# bazel run //modules/tools/planning:test_case
coords = {0: {'x': 586952.4339599609, 'y': 4141242.6538391113, 'theta': -0.3024105043029949}, -1: {'x': 586951.4796911987, 'y': 4141242.9515512963, 'theta': -0.3024105043029949}, -2: {'x': 586950.5250698371, 'y': 4141243.249373485, 'theta': -0.3024105043029949},
          - 3: {'x': 586949.5704484755, 'y': 4141243.5471956735, 'theta': -0.3024105043029949}, -4: {'x': 586948.6158271139, 'y': 4141243.845017862, 'theta': -0.3024105043029949}, -5: {'x': 586947.6612057523, 'y': 4141244.1428400506, 'theta': -0.3024105043029949}}


def send_localization(dist):
    assert dist in coords
    loc = LocalizationEstimate()
    loc.header.sequence_num = 0
    loc.header.module_name = "test_case"
    loc.header.timestamp_sec = cyber_time.Time.now().to_sec()
    loc.pose.position.x = coords[dist]['x']
    loc.pose.position.y = coords[dist]['y']
    loc.pose.heading = coords[dist]['theta']

    for i in range(5):
        loc.header.sequence_num = i
        localization_writer.write(loc)
        sleep(0.5)


def main():
    send_localization(-2)


if __name__ == '__main__':
    main()
