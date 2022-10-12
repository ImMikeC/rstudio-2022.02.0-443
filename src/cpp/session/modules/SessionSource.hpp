/*
 * SessionSource.hpp
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

#ifndef SESSION_SOURCE_HPP
#define SESSION_SOURCE_HPP

#include <vector>

#include <boost/shared_ptr.hpp>

#include <shared_core/json/Json.hpp>

namespace rstudio {
namespace core {
   class Error;
   namespace r_util {
      class RSourceIndex;
   }
}
}
 
namespace rstudio {
namespace session {
namespace modules { 
namespace source {
   
core::Error clientInitDocuments(core::json::Array* pJsonDocs);

core::Error initialize();
                       
} // namespace source
} // namespace modules
} // namespace session
} // namespace rstudio

#endif // SESSION_SOURCE_HPP