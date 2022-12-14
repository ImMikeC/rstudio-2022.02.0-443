/*
 * popup.tsx
 *
 * Copyright (C) 2022 by RStudio, PBC
 *
 * Unless you have received this program directly from RStudio pursuant
 * to the terms of a commercial license agreement with RStudio, then
 * this program is licensed to you under the terms of version 3 of the
 * GNU Affero General Public License. This program is distributed WITHOUT
 * ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
 * MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
 * AGPL (http://www.gnu.org/licenses/agpl-3.0.txt) for more details.
 *
 */

import React from 'react';

import { WidgetProps } from './react';

export type PopupProps = WidgetProps;

export const Popup: React.FC<PopupProps> = props => {
  const className = ['pm-popup', 'pm-text-color', 'pm-proportional-font', 'pm-pane-border-color', 'pm-background-color']
    .concat(props.classes || [])
    .join(' ');

  const style: React.CSSProperties = {
    ...props.style,
    position: 'absolute',
    zIndex: 10,
  };

  return (
    <div className={className} style={style} contentEditable={false} suppressContentEditableWarning={true}>
      {props.children}
    </div>
  );
};
