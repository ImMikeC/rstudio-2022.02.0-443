/*
 * PlumberAPIStatusEvent.java
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
package org.rstudio.studio.client.plumber.events;

import org.rstudio.core.client.js.JavaScriptSerializable;
import org.rstudio.studio.client.application.events.CrossWindowEvent;
import org.rstudio.studio.client.plumber.model.PlumberAPIParams;

import com.google.gwt.event.shared.EventHandler;
import com.google.gwt.event.shared.GwtEvent;

@JavaScriptSerializable
public class PlumberAPIStatusEvent 
   extends CrossWindowEvent<PlumberAPIStatusEvent.Handler>
{ 
   public interface Handler extends EventHandler
   {
      void onPlumberAPIStatus(PlumberAPIStatusEvent event);
   }

   public static final GwtEvent.Type<PlumberAPIStatusEvent.Handler> TYPE = new GwtEvent.Type<>();
   
   public PlumberAPIStatusEvent()
   {
   }
   
   public PlumberAPIStatusEvent(PlumberAPIParams params)
   {
      this(params, false);
   }

   public PlumberAPIStatusEvent(PlumberAPIParams params, boolean serverInitiated)
   {
      params_ = params;
      serverInitiated_ = serverInitiated;
   }
   
   public PlumberAPIParams getParams()
   {
      return params_;
   }
   
   public boolean isServerInitiated()
   {
      return serverInitiated_;
   }
   
   @Override
   public boolean forward()
   {
      return false;
   }
   
   @Override
   protected void dispatch(PlumberAPIStatusEvent.Handler handler)
   {
      handler.onPlumberAPIStatus(this);
   }

   @Override
   public GwtEvent.Type<PlumberAPIStatusEvent.Handler> getAssociatedType()
   {
      return TYPE;
   }
   
   private PlumberAPIParams params_;
   private boolean serverInitiated_;
}