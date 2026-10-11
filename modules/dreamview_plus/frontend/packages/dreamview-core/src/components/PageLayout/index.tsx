import React, { useCallback, useState } from 'react';
import { PageLayoutStoreProvider } from '@dreamview/dreamview-core/src/store/PageLayoutStore';
import { usePickHmiStore, CURRENT_MODE } from '@dreamview/dreamview-core/src/store/HmiStore';
import { flushSync } from 'react-dom';
import Menu from '../Menu';
import PanelLayout from '../PanelLayout';
import MenuDrawer from '../MenuDrawer';
import usePageLayoutStyles from './style';
import PerceptionGuide from '../Guide/PerceptionGuide';
import DefaultGuide from '../Guide/DefaultGuide';
import PNCGuide from '../Guide/PNCGuide';
import useComponentDisplay from '../../hooks/useComponentDisplay';
import VehicleGuide from '../Guide/VehicleGuide';
import BottomBar from '../BottomBar';

function PageLayout() {
    const [hmi] = usePickHmiStore();

    const { classes: c, cx, css } = usePageLayoutStyles();

    const [enterGuideState, setEnterGuideState] = useState({ currentMode: '' });

    const [{ isBottomBarShow }] = useComponentDisplay();

    const [perceptionGuideLastStep, setPerceptionGuideLastState] = useState({});

    const controlPerceptionGuideLastStep = useCallback((perceptionGuideLastStepStyle: object) => {
        setPerceptionGuideLastState(perceptionGuideLastStepStyle);
    }, []);

    const setEnterGuideStateMemo = useCallback((currentMode: CURRENT_MODE) => {
        flushSync(() => {
            setEnterGuideState({ currentMode: '' });
        });
        setEnterGuideState(() => ({ currentMode }));
    }, []);

    return (
        <div className={c['dv-root']}>
            {enterGuideState.currentMode === CURRENT_MODE.DEFAULT && <DefaultGuide />}
            {enterGuideState.currentMode === CURRENT_MODE.PERCEPTION && (
                <PerceptionGuide controlPerceptionGuideLastStep={controlPerceptionGuideLastStep} />
            )}
            {enterGuideState.currentMode === CURRENT_MODE.PNC && <PNCGuide />}
            {enterGuideState.currentMode === CURRENT_MODE.VEHICLE_TEST && (
                <VehicleGuide currentOperation={hmi.currentOperation} />
            )}
            <div className={c['dv-layout-menu']}>
                <Menu setEnterGuideStateMemo={setEnterGuideStateMemo} />
            </div>
            <div className={c['dv-layout-content']}>
                <div className={c['dv-layout-window']}>
                    <MenuDrawer />
                    <div className={cx(c['dv-layout-panellayout'])}>
                        <div id='perception-guide-perceived-effects' className={css(perceptionGuideLastStep)} />
                        <PanelLayout />
                    </div>
                </div>
                <div
                    className={cx(c['dv-layout-playercontrol'], {
                        [c['dv-layout-playercontrol-active']]: isBottomBarShow,
                    })}
                >
                    <BottomBar />
                </div>
            </div>
        </div>
    );
}

const PageLayoutMemo = React.memo(PageLayout);

function PageLayoutWrapper() {
    return (
        <PageLayoutStoreProvider>
            <PageLayoutMemo />
        </PageLayoutStoreProvider>
    );
}
export default React.memo(PageLayoutWrapper);
